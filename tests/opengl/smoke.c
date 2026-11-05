/* Windows desktop WGL/GL 3.0 acceptance probe. Run both architectures IN BCD.
 * This program is not a host/simulator rendering test. --disabled expects failure.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <GL/gl.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#ifndef GL_VERTEX_SHADER
#define GL_VERTEX_SHADER 0x8B31
#define GL_FRAGMENT_SHADER 0x8B30
#define GL_COMPILE_STATUS 0x8B81
#define GL_LINK_STATUS 0x8B82
#define GL_FRAMEBUFFER 0x8D40
#define GL_FRAMEBUFFER_COMPLETE 0x8CD5
#define GL_COLOR_ATTACHMENT0 0x8CE0
#define GL_SHADING_LANGUAGE_VERSION 0x8B8C
#endif
typedef HGLRC(WINAPI *CreateAttribs)(HDC,HGLRC,const int*);
typedef BOOL(WINAPI *SwapInterval)(int);
#define PROC(ret,name,args) static ret(APIENTRY *name)args
PROC(GLuint,CreateShader,(GLenum));PROC(void,ShaderSource,(GLuint,GLsizei,const char *const*,const GLint*));
PROC(void,CompileShader,(GLuint));PROC(void,GetShaderiv,(GLuint,GLenum,GLint*));
PROC(void,GetShaderInfoLog,(GLuint,GLsizei,GLsizei*,char*));PROC(GLuint,CreateProgram,(void));
PROC(void,AttachShader,(GLuint,GLuint));PROC(void,LinkProgram,(GLuint));PROC(void,UseProgram,(GLuint));
PROC(void,GetProgramiv,(GLuint,GLenum,GLint*));PROC(void,DeleteShader,(GLuint));PROC(void,DeleteProgram,(GLuint));
PROC(void,GenFramebuffers,(GLsizei,GLuint*));PROC(void,BindFramebuffer,(GLenum,GLuint));
PROC(void,FramebufferTexture2D,(GLenum,GLenum,GLenum,GLuint,GLint));PROC(GLenum,CheckFramebufferStatus,(GLenum));
PROC(void,DeleteFramebuffers,(GLsizei,const GLuint*));
static int failure;
#define CHECK(x) do { if(!(x)){fprintf(stderr,"[gl-smoke] FAIL line=%d: %s error=%lu GL=%x\n",__LINE__,#x,GetLastError(),glGetError());failure=1;goto cleanup;} }while(0)
#define LOAD(name) do { name=(void*)wglGetProcAddress("gl" #name);CHECK(name); }while(0)
static GLuint shader(GLenum kind,const char *source) {
 GLuint s=CreateShader(kind);GLint ok=0;ShaderSource(s,1,&source,NULL);CompileShader(s);GetShaderiv(s,GL_COMPILE_STATUS,&ok);
 if(!ok){char log[2048];GetShaderInfoLog(s,sizeof(log),NULL,log);fprintf(stderr,"[gl-smoke] shader %s\n",log);return 0;}return s;
}
static LRESULT CALLBACK window_proc(HWND h,UINT m,WPARAM w,LPARAM l){return DefWindowProcA(h,m,w,l);}
int main(int argc,char **argv) {
 freopen("bcd-opengl-smoke.log","w",stderr);setvbuf(stderr,NULL,_IONBF,0);
 fprintf(stderr,"[gl-smoke] pointerBits=%u disabled=%d\n",(unsigned)(8*sizeof(void*)),argc>1);
 WNDCLASSA cls={0};cls.style=CS_OWNDC;cls.lpfnWndProc=window_proc;cls.hInstance=GetModuleHandleA(NULL);cls.lpszClassName="BCDGLSmoke";
 RegisterClassA(&cls);HWND window=CreateWindowA(cls.lpszClassName,"BCD desktop OpenGL smoke",WS_OVERLAPPEDWINDOW|WS_VISIBLE,0,0,640,360,NULL,NULL,cls.hInstance,NULL);
 HDC dc=GetDC(window);HGLRC legacy=NULL,context=NULL,shared=NULL;GLuint tex=0,fbo=0,vs=0,fs=0,program=0;
 PIXELFORMATDESCRIPTOR fmt={sizeof(fmt),1,PFD_DRAW_TO_WINDOW|PFD_SUPPORT_OPENGL|PFD_DOUBLEBUFFER,PFD_TYPE_RGBA,32};
 int pf=ChoosePixelFormat(dc,&fmt);
 if(argc>1 && !strcmp(argv[1],"--disabled")) {
  if(pf && SetPixelFormat(dc,pf,&fmt))legacy=wglCreateContext(dc);
  failure=legacy!=NULL;fprintf(stderr,"[gl-smoke] disabled context=%p %s\n",legacy,failure?"FAIL":"PASS");goto cleanup;
 }
 CHECK(pf);CHECK(SetPixelFormat(dc,pf,&fmt));legacy=wglCreateContext(dc);CHECK(legacy);CHECK(wglMakeCurrent(dc,legacy));
 CreateAttribs create=(CreateAttribs)wglGetProcAddress("wglCreateContextAttribsARB");CHECK(create);
 int attrs[]={0x2091,3,0x2092,0,0};context=create(dc,NULL,attrs);CHECK(context);CHECK(wglMakeCurrent(dc,context));
 fprintf(stderr,"[gl-smoke] vendor=%s renderer=%s version=%s GLSL=%s\n",glGetString(GL_VENDOR),glGetString(GL_RENDERER),glGetString(GL_VERSION),glGetString(GL_SHADING_LANGUAGE_VERSION));
 CHECK(strstr((char*)glGetString(GL_RENDERER),"zink"));
 CHECK(!strstr((char*)glGetString(GL_RENDERER),"llvmpipe"));
 shared=create(dc,context,attrs);CHECK(shared);CHECK(!wglGetProcAddress("bcdDeliberatelyMissingFunction"));
 LOAD(CreateShader);LOAD(ShaderSource);LOAD(CompileShader);LOAD(GetShaderiv);LOAD(GetShaderInfoLog);
 LOAD(CreateProgram);LOAD(AttachShader);LOAD(LinkProgram);LOAD(UseProgram);LOAD(GetProgramiv);LOAD(DeleteShader);LOAD(DeleteProgram);
 LOAD(GenFramebuffers);LOAD(BindFramebuffer);LOAD(FramebufferTexture2D);LOAD(CheckFramebufferStatus);LOAD(DeleteFramebuffers);
 vs=shader(GL_VERTEX_SHADER,"#version 130\nvoid main(){gl_Position=gl_Vertex;gl_TexCoord[0]=gl_MultiTexCoord0;}");CHECK(vs);
 fs=shader(GL_FRAGMENT_SHADER,"#version 130\nuniform sampler2D image;void main(){gl_FragColor=texture2D(image,gl_TexCoord[0].xy);}");CHECK(fs);
 program=CreateProgram();AttachShader(program,vs);AttachShader(program,fs);LinkProgram(program);GLint linked;GetProgramiv(program,GL_LINK_STATUS,&linked);CHECK(linked);
 unsigned char pixels[]={255,0,0,255,0,255,0,255,0,0,255,128,255,255,255,255};
 glGenTextures(1,&tex);glBindTexture(GL_TEXTURE_2D,tex);glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,2,2,0,GL_RGBA,GL_UNSIGNED_BYTE,pixels);
 glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
 GenFramebuffers(1,&fbo);BindFramebuffer(GL_FRAMEBUFFER,fbo);FramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,tex,0);
 CHECK(CheckFramebufferStatus(GL_FRAMEBUFFER)==GL_FRAMEBUFFER_COMPLETE);unsigned char pixel[4];glReadPixels(0,0,1,1,GL_RGBA,GL_UNSIGNED_BYTE,pixel);CHECK(pixel[0]==255 && pixel[1]==0);
 BindFramebuffer(GL_FRAMEBUFFER,0);SwapInterval interval=(SwapInterval)wglGetProcAddress("wglSwapIntervalEXT");CHECK(interval);CHECK(interval(1));
 LARGE_INTEGER start,end,frequency;QueryPerformanceFrequency(&frequency);QueryPerformanceCounter(&start);
 for(int i=0;i<240;i++) {
  MSG msg;while(PeekMessageA(&msg,NULL,0,0,PM_REMOVE)){TranslateMessage(&msg);DispatchMessageA(&msg);}
  if(i==120){SetWindowPos(window,NULL,0,0,800,450,SWP_NOMOVE|SWP_NOZORDER);CHECK(interval(0));}
  RECT client;GetClientRect(window,&client);glViewport(0,0,client.right,client.bottom);glClearColor(0.03f,0.05f,0.1f,1);glClear(GL_COLOR_BUFFER_BIT);
  UseProgram(program);glBegin(GL_QUADS);glTexCoord2f(0,0);glVertex2f(-.8f,-.8f);glTexCoord2f(1,0);glVertex2f(.8f,-.8f);glTexCoord2f(1,1);glVertex2f(.8f,.8f);glTexCoord2f(0,1);glVertex2f(-.8f,.8f);glEnd();
  CHECK(glGetError()==GL_NO_ERROR);CHECK(SwapBuffers(dc));
 }
 QueryPerformanceCounter(&end);fprintf(stderr,"[gl-smoke] PASS 240 textured shader frames + FBO/readback + resize + intervals; elapsed=%.3fs\n",(double)(end.QuadPart-start.QuadPart)/frequency.QuadPart);
 cleanup:
 if(context){if(wglMakeCurrent(dc,context)){if(program)DeleteProgram(program);if(vs)DeleteShader(vs);if(fs)DeleteShader(fs);if(fbo)DeleteFramebuffers(1,&fbo);if(tex)glDeleteTextures(1,&tex);}}
 wglMakeCurrent(NULL,NULL);if(shared)wglDeleteContext(shared);if(context)wglDeleteContext(context);if(legacy)wglDeleteContext(legacy);
 ReleaseDC(window,dc);DestroyWindow(window);fprintf(stderr,"[gl-smoke] cleanup %s\n",failure?"FAIL":"PASS");return failure;
}
