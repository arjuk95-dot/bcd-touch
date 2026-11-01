/* SPDX-License-Identifier: GPL-3.0-or-later
 * WO-BCD-TOUCH-001. Guest-side evidence recorder; no synthetic input.
 * Build: x86_64-w64-mingw32-clang xinput-trace.c -O2 -mwindows -luser32 -lxinput -o bcd-touch-input-trace-x64.exe
 * Start toggles recording. Touch gameplay controls only while recording.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <xinput.h>
#include <stdio.h>
#include <string.h>
static FILE *logfile;
static LARGE_INTEGER frequency;
static unsigned long keys,mouse,raw_keys,raw_mouse;
static int armed,previous_start;
static XINPUT_STATE last;
static DWORD last_result=~0u;
static double now(void) { LARGE_INTEGER t; QueryPerformanceCounter(&t); return (double)t.QuadPart/frequency.QuadPart; }
static void record(DWORD result,const XINPUT_STATE *s) {
    const XINPUT_GAMEPAD *p=&s->Gamepad;
    int simultaneous=p->sThumbLX!=0 && p->bRightTrigger>0 && (p->sThumbRX!=0 || p->sThumbRY!=0);
    if (!logfile) return;
    fprintf(logfile,"{\"t\":%.6f,\"slot\":0,\"result\":%lu,\"buttons\":%u,\"lt\":%u,\"rt\":%u,\"lx\":%d,\"ly\":%d,\"rx\":%d,\"ry\":%d,\"keyEvents\":%lu,\"mouseEvents\":%lu,\"rawKeyEvents\":%lu,\"rawMouseEvents\":%lu,\"simultaneous\":%s}\n",now(),(unsigned long)result,p->wButtons,p->bLeftTrigger,p->bRightTrigger,p->sThumbLX,p->sThumbLY,p->sThumbRX,p->sThumbRY,keys,mouse,raw_keys,raw_mouse,simultaneous?"true":"false");
    fflush(logfile);
}
static LRESULT CALLBACK proc(HWND window,UINT message,WPARAM w,LPARAM l) {
    if(message==WM_CREATE) {
        RAWINPUTDEVICE devices[2]={{1,6,0,window},{1,2,0,window}};
        RegisterRawInputDevices(devices,2,sizeof(devices[0])); SetTimer(window,1,4,NULL);return 0;
    }
    if(message==WM_TIMER) {
        XINPUT_STATE s; memset(&s,0,sizeof(s));DWORD result=XInputGetState(0,&s);
        int start=(s.Gamepad.wButtons&XINPUT_GAMEPAD_START)!=0;
        if(start&&!previous_start) {armed=!armed;keys=mouse=raw_keys=raw_mouse=0;if(logfile)fprintf(logfile,"{\"armed\":%s,\"t\":%.6f}\n",armed?"true":"false",now());}
        previous_start=start;
        if(armed&&(result!=last_result||memcmp(&last.Gamepad,&s.Gamepad,sizeof(s.Gamepad)))) record(result,&s);
        last=s;last_result=result;InvalidateRect(window,NULL,FALSE);return 0;
    }
    if(armed && (message==WM_KEYDOWN||message==WM_KEYUP||message==WM_SYSKEYDOWN||message==WM_SYSKEYUP))keys++;
    if(armed && message>=WM_MOUSEFIRST && message<=WM_MOUSELAST)mouse++;
    if(armed && message==WM_INPUT) {
        RAWINPUT input;UINT size=sizeof(input);
        if(GetRawInputData((HRAWINPUT)l,RID_INPUT,&input,&size,sizeof(RAWINPUTHEADER))!=(UINT)-1) {
            if(input.header.dwType==RIM_TYPEKEYBOARD)raw_keys++;
            if(input.header.dwType==RIM_TYPEMOUSE)raw_mouse++;
        }
    }
    if(message==WM_PAINT) {
        PAINTSTRUCT ps;HDC dc=BeginPaint(window,&ps);char text[512];
        snprintf(text,sizeof(text),"BCD Touch guest trace — %s\nPress controller Menu/Start to arm/disarm.\nSlot 0: LS %d,%d  RT %u  RS %d,%d\nKeys %lu  Mouse %lu  Raw keys %lu  Raw mouse %lu\nOutput: touch-input-trace.jsonl\nNo input is synthesized by this program.",armed?"RECORDING":"idle",last.Gamepad.sThumbLX,last.Gamepad.sThumbLY,last.Gamepad.bRightTrigger,last.Gamepad.sThumbRX,last.Gamepad.sThumbRY,keys,mouse,raw_keys,raw_mouse);
        RECT r={12,12,980,400};DrawTextA(dc,text,-1,&r,DT_LEFT|DT_WORDBREAK);EndPaint(window,&ps);return 0;
    }
    if(message==WM_DESTROY) {if(armed)record(last_result,&last);if(logfile)fclose(logfile);PostQuitMessage(0);return 0;}
    return DefWindowProcA(window,message,w,l);
}
int WINAPI WinMain(HINSTANCE instance,HINSTANCE previous,LPSTR command,int show) {
    (void)previous;(void)command;QueryPerformanceFrequency(&frequency);logfile=fopen("touch-input-trace.jsonl","a");
    WNDCLASSA c;memset(&c,0,sizeof(c));c.lpfnWndProc=proc;c.hInstance=instance;c.lpszClassName="BCDTouchTrace";c.hbrBackground=(HBRUSH)(COLOR_WINDOW+1);RegisterClassA(&c);
    HWND window=CreateWindowA(c.lpszClassName,"BCD Touch guest evidence",WS_OVERLAPPEDWINDOW,0,0,1000,500,NULL,NULL,instance,NULL);ShowWindow(window,show);
    MSG message;while(GetMessageA(&message,NULL,0,0)>0) {TranslateMessage(&message);DispatchMessageA(&message);}return 0;
}
