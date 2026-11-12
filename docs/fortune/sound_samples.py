import numpy as np, wave, subprocess
from scipy.signal import butter, sosfilt
sr=44100
rng=np.random.default_rng(5)
def save(name,y):
    y=y/np.max(np.abs(y))*0.9
    with wave.open(name+'.wav','w') as o:
        o.setnchannels(1);o.setsampwidth(2);o.setframerate(sr);o.writeframes((y*32767).astype(np.int16).tobytes())
    subprocess.run(['ffmpeg','-loglevel','error','-y','-i',name+'.wav','-c:a','aac','-b:a','192k',name+'.m4a'])
def t(d): return np.arange(int(d*sr))/sr
def bell(f,d,decay=1.2,partials=((1,1),(2.0,0.5),(2.76,0.35),(5.4,0.15),(8.9,0.06))):
    x=t(d); y=sum(a*np.sin(2*np.pi*f*m*x)*np.exp(-x*m**0.5/decay) for m,a in partials)
    y[:int(0.003*sr)]*=np.linspace(0,1,int(0.003*sr)); return y
def ting(f,d=1.0,decay=0.35):
    x=t(d); y=(np.sin(2*np.pi*f*x)+0.3*np.sin(2*np.pi*f*2.01*x))*np.exp(-x/decay)
    y[:int(0.002*sr)]*=np.linspace(0,1,int(0.002*sr)); return y
def sweep_noise(d,f0,f1,shape):
    n=rng.standard_normal(int(d*sr)); out=np.zeros_like(n); blk=1024
    for i in range(0,len(n),blk):
        fr=i/len(n); fc=f0+(f1-f0)*fr
        sos=butter(2,[max(80,fc*0.6),min(sr/2-100,fc*1.6)],'bandpass',fs=sr,output='sos')
        out[i:i+blk]=sosfilt(sos,n[i:i+blk])
    env=shape(np.linspace(0,1,len(n))); return out*env
def place(buf,sig,at):
    s=int(at*sr); e=min(len(buf),s+len(sig)); buf[s:e]+=sig[:e-s]; return buf
def reverb(y,amt=0.25):
    out=y.copy()
    for dly,g in [(0.031,0.5),(0.047,0.42),(0.071,0.33),(0.097,0.25),(0.13,0.18)]:
        k=int(dly*sr); out[k:]+=y[:-k]*g*amt*2
    return out
# Pops
p=np.zeros(int(1.3*sr)); p=place(p,sweep_noise(0.45,500,3500,lambda u:np.sin(np.pi*u)**2)*0.5,0); p=place(p,ting(2637,1.0,0.4)*0.6,0.38); save('pop1_mist',reverb(p))
p=np.zeros(int(1.1*sr)); th=np.sin(2*np.pi*180*t(0.12))*np.exp(-t(0.12)/0.03); p=place(p,th*0.6,0); p=place(p,ting(2637,0.9,0.3)*0.5,0.03); p=place(p,ting(3951,0.9,0.28)*0.4,0.12); save('pop2_glass',reverb(p))
p=np.zeros(int(1.5*sr)); p=place(p,sweep_noise(0.55,3000,600,lambda u:(1-u)**1.5*np.minimum(1,u*20))*0.5,0); p=place(p,bell(880,1.3,0.9)*0.35,0.05); p=place(p,ting(3520,1.0,0.5)*0.25,0.1); save('pop3_sigh',reverb(p,0.35))
p=np.zeros(int(1.4*sr)); sw=sweep_noise(0.3,800,5000,lambda u:u**2)*0.4; p=place(p,sw,0); p=place(p,ting(3136,1.0,0.45)*0.6,0.3)
for k,(f,a) in enumerate([(4186,.2),(5274,.15),(6272,.12),(5274,.1)]): p=place(p,ting(f,0.5,0.12)*a,0.42+k*0.07)
save('pop4_star',reverb(p))
# Oracle alarm previews (10 s each; final files 28 s with the same build)
D=10
def swell(n,start=0.35): return np.linspace(start,1,n)
a=np.zeros(int(D*sr))
for k in range(5): a=place(a,bell(220,2.5,1.4)*0.5+bell(440,2.5,1.0)*0.2,k*2.0)
a*=swell(len(a)); save('oracle1_warm_bell',reverb(a,0.3))
b=np.zeros(int(D*sr)); x=t(D); bowl=(np.sin(2*np.pi*196*x)+0.6*np.sin(2*np.pi*198.5*x)+0.3*np.sin(2*np.pi*527*x))*0.25
b+=bowl*np.minimum(1,x/1.5)
for k in range(4): b=place(b,bell(196,3,1.8)*0.6,k*2.6)
b*=swell(len(b),0.3); save('oracle2_singing_bowl',reverb(b,0.3))
c=np.zeros(int(D*sr))
for k in range(5):
    for j,f in enumerate([440,554.4,659.3]): c=place(c,bell(f,1.6,0.8)*0.45,k*2.0+j*0.22)
c*=swell(len(c)); save('oracle3_chime_ladder',reverb(c,0.3))
d=np.zeros(int(D*sr)); pad=np.sin(2*np.pi*110*x)*(0.5+0.5*np.sin(2*np.pi*0.66*x))*0.25; d+=pad
for k in range(7): d=place(d,ting(1318.5,1.2,0.5)*0.5+bell(659,1.2,0.6)*0.25,0.4+k*1.4)
d*=swell(len(d),0.3); save('oracle4_pulse',reverb(d,0.3))
