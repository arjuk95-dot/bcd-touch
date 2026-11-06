#!/usr/bin/env python3
"""Exercise production mouse injection/reporting with a simulated Wine server.

Checks the Dock/desktop regression: relative input was accepted, but no guest
position reached the compositor. No UIKit, game, or phone is simulated here.
"""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
driver = (root / 'build/win32u-unix/driver_ios.c').read_text(encoding='utf-8')

def function(signature):
    start = driver.index(signature)
    return driver[start:driver.index('\n}', start) + 2]

code = r'''
#include <assert.h>
#include <stdio.h>
#define MOUSEEVENTF_MOVE 1u
#define INPUT_MOUSE 0
#define TRUE 1
#define STATUS_PENDING 0x103
#define OBJECT_LOCK_INIT {0}
typedef int BOOL;
typedef int INT;
typedef int NTSTATUS;
typedef void *HWND;
struct object_lock { int read; };
struct rectangle { int left, top, right, bottom; };
typedef struct { struct { int x,y; struct rectangle clip; } cursor; } desktop_shm_t;
typedef struct { int type; struct { int dx,dy; unsigned mouseData,dwFlags,time,dwExtraInfo; } mi; } INPUT;
static desktop_shm_t desktop = {{321,222,{0,0,1280,720}}};
static int desktop_mode, enabled=1, pack, reports, warps, posts, foregrounds, px,py;
static struct rectangle reported_clip;
static int winios_desktop_mode(void) { return desktop_mode; }
static int direct_wanted(void) { return enabled; }
static int pack_wanted(void) { return pack; }
static int (*winios_direct_cursor_wanted)(void)=direct_wanted;
static int (*winios_cursor_pack_wanted)(void)=pack_wanted;
static void report_clip(int l,int t,int r,int b) { reported_clip=(struct rectangle){l,t,r,b}; }
static void (*winios_direct_cursor_clip)(int,int,int,int)=report_clip;
static void winios_direct_cursor_pos(int x,int y) { reports++;px=x;py=y; }
static void report_warp(int x,int y) { warps++;px=x;py=y; }
static void (*winios_direct_cursor_warp)(int,int)=report_warp;
static int get_shared_desktop(struct object_lock *lock,const desktop_shm_t **data) {
    *data=&desktop;return lock->read++ ? 0:STATUS_PENDING;
}
static void ios_foreground_if_none(const char *why) { (void)why;foregrounds++; }
static NTSTATUS send_hardware_message(HWND hwnd,int a,const INPUT *i,int b) {
    (void)a;(void)b;assert(!hwnd);posts++;
    // This path must inject only the original deltas, never an estimated absolute position.
    assert(!(i->mi.dwFlags & 0x8000));
    if (i->mi.dwFlags & MOUSEEVENTF_MOVE) {
        desktop.cursor.x+=i->mi.dx;desktop.cursor.y+=i->mi.dy;
        if(desktop.cursor.x<0)desktop.cursor.x=0;
        if(desktop.cursor.x>=1280)desktop.cursor.x=1279;
        if(desktop.cursor.y<0)desktop.cursor.y=0;
        if(desktop.cursor.y>=720)desktop.cursor.y=719;
    }
    return 0;
}
''' + '\n'.join(function(s) for s in (
    'static int winios_direct_cursor_on(void)',
    'static int winios_cursor_position_wanted(void)',
    'static void winios_report_cursor_pos(void)',
    'static BOOL winios_drv_set_cursor_pos( INT x, INT y )',
    'void winios_drv_post_mouse(int x, int y, unsigned int flags, unsigned int mouse_data, HWND hwnd)',
)) + r'''
int main(void) {
    desktop_mode=1;
    // Existing desktop/physical path: no new reporting or cursor warp.
    winios_drv_post_mouse(4,5,1,0,NULL);assert(posts==1 && reports==0);
    assert(winios_drv_set_cursor_pos(7,8));assert(warps==0);
    pack=1;
    // A swipe reports Wine's accumulated position, including its clip bounds.
    winios_drv_post_mouse(10,-12,1,0,NULL);
    assert(posts==2 && reports==1 && px==335 && py==215);
    assert(reported_clip.right==1280 && reported_clip.bottom==720);
    winios_drv_post_mouse(-999,999,1,0,NULL);assert(px==0 && py==719);
    // Clicks neither move the cursor nor manufacture extra movement events.
    winios_drv_post_mouse(0,0,2,0,NULL);winios_drv_post_mouse(0,0,4,0,NULL);
    assert(posts==5 && reports==2 && px==0 && py==719);
    // Guest SetCursorPos remains observable without injecting another event.
    winios_drv_set_cursor_pos(640,360);assert(warps==1 && px==640 && py==360 && posts==5);
    pack=0;winios_drv_set_cursor_pos(9,9);assert(warps==1);
    winios_drv_post_mouse(1,1,1,0,NULL);assert(reports==2);
    // Original direct-mode hardware reporting remains available.
    desktop_mode=0;winios_drv_post_mouse(3,-3,1,0,NULL);assert(reports==3);
    enabled=0;winios_drv_post_mouse(1,1,1,0,NULL);assert(reports==3);
    assert(posts==8 && foregrounds==posts);
    puts("PASS: relative cursor reports in desktop packs; clipping, clicks, warps and stock routes");
}
'''
with tempfile.TemporaryDirectory(prefix='bcd-cursor-desktop-') as tmp:
    src, exe = Path(tmp)/'probe.c', Path(tmp)/'probe'
    src.write_text(code, encoding='utf-8')
    subprocess.run([os.environ.get('CC','cc'),'-Wall','-Wextra','-Werror',str(src),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)

# Check the app opts in only for cursor packs and never guesses a cursor origin.
app=(root/'app/Madeira/HardwareInput.swift').read_text(encoding='utf-8')
assert 'winios_cursor_pack_track(active ? 1:0)' in app
assert 'if cursorPackActive && Self.desktopMode { winios_cursor_move(cursorState.x,cursorState.y) }' in app
start=app.index('func postCursorPackRelative(')
relative=app[start:app.index('\n    }',start)]
assert 'winios_pointer(dx,dy,Self.moveFlag,0)' in relative and 'absoluteFlag' not in relative
assert 'if (winios_direct_cursor_pos)\n            winios_user_driver.pSetCursorPos' in driver
print('PASS: app follows reported guest position; no absolute synchronization on touch-down')
