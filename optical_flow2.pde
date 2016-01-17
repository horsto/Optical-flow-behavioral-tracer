// Behavioral Neuroscience Tracer 
// last update: 18-05-2014
/* 

//////////////////////////////////////////////////////////////////////////////////////////////
by Horst Obenhaus (hobenhaus@gmail.com) - 2013
based on the optical flow algorithm by Hidetoshi Shimodaira (shimo@is.titech.ac.jp 2010 GPL)
uses the OneEuroFilter for signal smoothing (http://www.lifl.fr/~casiez/1euro/) 
and the cp5 library for GUI elements (http://www.sojamo.de/libraries/controlP5/)

 
This program provides a solution for quick and dirty tracing of behavioral experiments with mice,
rats, etc. in a wide range of settings and recognized USB Cameras. 

How to use:
Application selects camera automatically on start-up. Change camera by hovering over "CAMERAS"
in the top left corner and select the appropiate camera.
To start tracing type in animal or trial name in the field highlighted at start-up
and the time in seconds you want the trace to be performed
IMPORTANT: Do not forget to type in name of current animal / trial!  Repeated names 
in between tracing starts will overwrite previous files!
Click on "Start" to start tracing (yellow bar will appear in top right corner for the length the 
trial. 
"Reset" will delete the traces that appeared since the start of the program. 

Thresholds for flow detection can be set by adjusting sliders on top. Not recommended!

Export: TXT file with 3 comma-separated columns: 
[0] - time in milliseconds since start of tracing
[1] - x 
[2] - y

 Export Structure: Date/Animal Name/txy_data 'Animal name'.txt
                   Date/Animal Name/trace date 'Animal name'.txt
 Start Export: Camera screenshot (gets refreshed by selecting a different camera option)

*/

//////////////////////////////////////////////////////////////////////////////////////////////
// parameters for desktop pc (high performance)
int wscreen=640;
int hscreen=480;

// for noise filtering
PVector noiseCoord;
PVector filteredCoord;
import signal.library.*;

// -----------------------------------------------------
// Create the filter
   SignalFilter myFilter;
// -----------------------------------------------------

// Parameters of the OneEuroFilter
float freq      = 30.0;
float minCutoff = 0.01; // decrease this to get rid of slow speed jitter
float beta      = 10.0;  // increase this to get rid of high speed lag
float dcutoff   = 1.0;

int gs=10; // grid step (pixels)
float predsec=.5; // prediction time (sec): larger for longer vector

// trace
int cols = 3;
int rows = 20000;
int[][] pos_x_y = new int[cols][rows];
int counter_trace = 0;
 
// parameters for laptop pc (low performance)
//int wscreen=480;
//int hscreen=360;
//int gs=20; // grid step (pixels)
//float predsec=1.0; // prediction time (sec): larger for longer vector
 
// use menus
import controlP5.*;
public MultiList l;
public ControlP5 cp5;
public ControlTimer c;
public Textlabel t;
 
 
///////////////////////////////////////////////
int counter_files = 0;

///////////////////////////////////////////////
public int recording_length;
public int saved_time;
public String recname = "              ";
///////////////////////////////////////////////
// use video
import processing.video.*;
Capture cam;
PFont font;
color[] vline;
String[] cameras;

int n =0; 
// capture parameters
int fps=30;
 
// use sound
import ddf.minim.*;
import ddf.minim.signals.*;
Minim minim;
AudioOutput audioout;
SineWave sine;
 
// grid parameters
 
int as=gs*2;  // window size for averaging (-as,...,+as)
int gw=wscreen/gs;
int gh=hscreen/gs;
int gs2=gs/2;
float df=predsec*fps;
 
// regression vectors
float[] fx, fy, ft;
int fm=3*9; // length of the vectors
 
// regularization term for regression
float fc=pow(11,8); // larger values for noisy video
// smoothing parameters
float wflow=0.3; // smaller value for longer smoothing
float threshold;
float threshold2;

 
// switch
boolean flagseg=false; // segmentation of moving objects?
boolean flagball=true; // playing ball game?
boolean flagmirror=true; // mirroring image?
boolean flagflow=true; //  draw opticalflow vectors?
boolean flagsound=true; // sound effect?
boolean flagimage=true; // show video image ?
boolean flagmovie=false; // saving movie?

boolean to_draw= false; // draw point in center of object
boolean save_frame = true;

public boolean recording_start;

// internally used variables
float ar,ag,ab; // used as return value of pixave
float[] dtr, dtg, dtb; // differentiation by t (red,gree,blue)
float[] dxr, dxg, dxb; // differentiation by x (red,gree,blue)
float[] dyr, dyg, dyb; // differentiation by y (red,gree,blue)
float[] par, pag, pab; // averaged grid values (red,gree,blue)
float[] flowx, flowy; // computed optical flow
float[] sflowx, sflowy; // slowly changing version of the flow
int clockNow,clockPrev, clockDiff; // for timing check
 
 
void setup(){
  // screen and video
  size(640, 480, JAVA2D); 
  
  // font
  font=createFont("helvetica",12);
  textFont(font);
  
  // noise filter:
  myFilter = new SignalFilter(this, 3);
   
  cp5 = new ControlP5(this);

  c = new ControlTimer();
  t = new Textlabel(cp5,"--",100,100);
  c.setSpeedOfTime(1);

  camera_detect();
  l = cp5.addMultiList("camera_list",10,35,70,15);
  MultiListButton b;
  b = l.add("CAMERAS",1);
  b.setColorBackground(color(70,70,80));
  // add some  sublists.
  for(int i=0;i < cameras.length;i++) {
    MultiListButton c = b.add("level1"+(i+1),i);
    c.setLabel(cameras[i]);
    c.setId(i);
    c.setColorBackground(color(0,64 + 2*i,64 + 5*i));
    c.setWidth(270);
  }
   cp5.addSlider("threshold")
     .setPosition(10,10)
     .setSize(200,15)
     .setRange(0,1)
     .setNumberOfTickMarks(0)
     .setSliderMode(Slider.FLEXIBLE)
     .setColorBackground(color(70,70,80)) 
     .setColorForeground(color(155))
     .setColorActive(color(10))
     .setValue(0.15)
     ;
    cp5.addSlider("threshold2")
     .setPosition(270,10)
     .setSize(200,15)
     .setRange(100000000,1475789056)
     .setNumberOfTickMarks(0)
     .setSliderMode(Slider.FLEXIBLE)
     .setColorBackground(color(70,70,80)) 
     .setColorForeground(color(155))
     .setColorActive(color(10))
     .setValue(214358881)
     ; 
    cp5.addButton("RESET")
     .setValue(0)
     .setPosition(10,height-30)
     .setSize(40,15)
     ;
   
    cp5.addTextfield("NAMEREC") 
     .setPosition(10,347)
     .setSize(60,20)
     .setFont(font)
     .setFocus(true)
     .setColor(color(255,255,255))
     .setAutoClear(false)
     .setColorActive(color(255,255,130)) 
     .setColor(color(255,255,255)) 
     //.setColorBackground(color(255,50,100)) 
     .setValue("mouse")
     .removeCallback() 
     ; 
     
    cp5.addTextfield("RECORDING LENGTH [s]") 
     .setPosition(10,385)
     .setSize(60,20)
     .setFont(font)
     .setFocus(false)
     .setColor(color(255,255,255))
     .setAutoClear(true)
     .setColorActive(color(255,255,130)) 
     ;  
    cp5.addButton("START")
     .setValue(1)
     .setPosition(10,430)
     .setSize(40,15)
     ; 
  
  // draw
  rectMode(CENTER);
  ellipseMode(CENTER);
  minim = new Minim(this);
  audioout = minim.getLineOut(Minim.STEREO, 4096);
  sine = new SineWave(440, 0.5, audioout.sampleRate());
  sine.portamento(200);
  sine.setAmp(0.0);
  audioout.addSignal(sine);
 
  // arrays
  par = new float[gw*gh];
  pag = new float[gw*gh];
  pab = new float[gw*gh];
  dtr = new float[gw*gh];
  dtg = new float[gw*gh];
  dtb = new float[gw*gh];
  dxr = new float[gw*gh];
  dxg = new float[gw*gh];
  dxb = new float[gw*gh];
  dyr = new float[gw*gh];
  dyg = new float[gw*gh];
  dyb = new float[gw*gh];
  flowx = new float[gw*gh];
  flowy = new float[gw*gh];
  sflowx = new float[gw*gh];
  sflowy = new float[gw*gh];
  fx = new float[fm];
  fy = new float[fm];
  ft = new float[fm];
  vline = new color[wscreen];
  recording_start = false;
}
 
 
// calculate average pixel value (r,g,b) for rectangle region
public void pixave(int x1, int y1, int x2, int y2) {
  float sumr,sumg,sumb;
  color pix;
  int r,g,b;
  int n;
  if(x1<0) x1=0;
  if(x2>=wscreen) x2=wscreen-1;
  if(y1<0) y1=0;
  if(y2>=hscreen) y2=hscreen-1;
 
  sumr=sumg=sumb=0.0;
  for(int y=y1; y<=y2; y++) {
    for(int i=wscreen*y+x1; i<=wscreen*y+x2; i++) {
      pix=cam.pixels[i];
      b=pix & 0xFF; // blue
      pix = pix >> 8;
      g=pix & 0xFF; // green
      pix = pix >> 8;
      r=pix & 0xFF; // red
      // averaging the values
      sumr += r;
      sumg += g;
      sumb += b;
    }
  }
  n = (x2-x1+1)*(y2-y1+1); // number of pixels
  // the results are stored in static variables
  ar = sumr/n;
  ag=sumg/n;
  ab=sumb/n;
}
 
// extract values from 9 neighbour grids
public void getnext9(float x[], float y[], int i, int j) {
  y[j+0] = x[i+0];
  y[j+1] = x[i-1];
  y[j+2] = x[i+1];
  y[j+3] = x[i-gw];
  y[j+4] = x[i+gw];
  y[j+5] = x[i-gw-1];
  y[j+6] = x[i-gw+1];
  y[j+7] = x[i+gw-1];
  y[j+8] = x[i+gw+1];
}
 
// solve optical flow by least squares (regression analysis)
void solveflow(int ig) {
  float xx, xy, yy, xt, yt;
  float a,u,v,w;
 
  // prepare covariances
  xx=xy=yy=xt=yt=0.0;
  for(int i=0;i<fm;i++) {
    xx += fx[i]*fx[i];
    xy += fx[i]*fy[i];
    yy += fy[i]*fy[i];
    xt += fx[i]*ft[i];
    yt += fy[i]*ft[i];
  }
 
  // least squares computation
  a = xx*yy - xy*xy + fc; // fc is for stable computation
  u = yy*xt - xy*yt; // x direction
  v = xx*yt - xy*xt; // y direction
 
  // write back
  flowx[ig] = -2*gs*u/a; // optical flow x (pixel per frame)
  flowy[ig] = -2*gs*v/a; // optical flow y (pixel per frame)

}
 
void draw() {
   wflow = threshold; // slider input!
   fc = threshold2; // slider input!
   
  if(cam.available()){
    // video capture
    cam.read();    
       
    // clock in msec
    clockNow = millis();
    clockDiff = clockNow - clockPrev;
    clockPrev = clockNow;
    
    // if time has run up: save data!
    if(clockNow-saved_time >= recording_length*1000 && recording_start){
       saveData();
    }
   
    // draw image
    if(flagimage){ 
      set(0,0,cam);
     if(save_frame){
     // save start frame
     saveFrame("field " + day() + "." + month() + "." + ".jpg");
     save_frame = false;
     }
    } else { background(0);}
  
  // show time during recording:
     if(recording_start){
     fill(255,255,255);
     t.setValue(c.toString());
     t.setPosition(width-67, height-29);
     t.draw(this);
     
    noStroke();
    fill(255,255,50);
    rect(580,18,90,15); 
   // rect(width/2,17,width-10,25);
    
     
    }
  

    // 1st sweep : differentiation by time
    for(int ix=0;ix<gw;ix++) {
      int x0=ix*gs+gs2;
      for(int iy=0;iy<gh;iy++) {
        int y0=iy*gs+gs2;
        int ig=iy*gw+ix;
        // compute average pixel at (x0,y0)
        pixave(x0-as,y0-as,x0+as,y0+as);
        // compute time difference
        dtr[ig] = ar-par[ig]; // red
        dtg[ig] = ag-pag[ig]; // green
        dtb[ig] = ab-pab[ig]; // blue
        // save the pixel
        par[ig]=ar;
        pag[ig]=ag;
        pab[ig]=ab;
      }
    }
 
    // 2nd sweep : differentiations by x and y
    for(int ix=1;ix<gw-1;ix++) {
      for(int iy=1;iy<gh-1;iy++) {
        int ig=iy*gw+ix;
        // compute x difference
        dxr[ig] = par[ig+1]-par[ig-1]; // red
        dxg[ig] = pag[ig+1]-pag[ig-1]; // green
        dxb[ig] = pab[ig+1]-pab[ig-1]; // blue
        // compute y difference
        dyr[ig] = par[ig+gw]-par[ig-gw]; // red
        dyg[ig] = pag[ig+gw]-pag[ig-gw]; // green
        dyb[ig] = pab[ig+gw]-pab[ig-gw]; // blue
      }
    }
 
    // 3rd sweep : solving optical flow
    for(int ix=1;ix<gw-1;ix++) {
      int x0=ix*gs+gs2;
      for(int iy=1;iy<gh-1;iy++) {
        int y0=iy*gs+gs2;
        int ig=iy*gw+ix;
 
        // prepare vectors fx, fy, ft
        getnext9(dxr,fx,ig,0); // dx red
        getnext9(dxg,fx,ig,9); // dx green
        getnext9(dxb,fx,ig,18);// dx blue
        getnext9(dyr,fy,ig,0); // dy red
        getnext9(dyg,fy,ig,9); // dy green
        getnext9(dyb,fy,ig,18);// dy blue
        getnext9(dtr,ft,ig,0); // dt red
        getnext9(dtg,ft,ig,9); // dt green
        getnext9(dtb,ft,ig,18);// dt blue
 
        // solve for (flowx, flowy) such that
        // fx flowx + fy flowy + ft = 0
        solveflow(ig);
 
        // smoothing
        sflowx[ig]+=(flowx[ig]-sflowx[ig])*wflow;
        sflowy[ig]+=(flowy[ig]-sflowy[ig])*wflow;
      }
    }
 
 
    // 4th sweep : draw the flow
    if(flagseg) {
      noStroke();
      fill(0);
      for(int ix=0;ix<gw;ix++) {
        int x0=ix*gs+gs2;
        for(int iy=0;iy<gh;iy++) {
          int y0=iy*gs+gs2;
          int ig=iy*gw+ix;
 
          float u=df*sflowx[ig];
          float v=df*sflowy[ig];
 
          float a=sqrt(u*u+v*v);
          if(a<15.0) rect(x0,y0,gs,gs);
        }
      }
    }
 
    // 5th sweep : draw the flow
    if(flagflow) {
      int[][] x_y = new int[2][640*480]; 
      int counter = 0;
      
      for(int ix=0;ix<gw;ix++) {
        int x0=ix*gs+gs2;
        for(int iy=0;iy<gh;iy++) {
          int y0=iy*gs+gs2;
          
          // save x0 and y0 into array
         
         
          int ig=iy*gw+ix;
 
          float u=df*sflowx[ig];
          float v=df*sflowy[ig];
 
          // draw the line segments for optical flow
          float a=sqrt(u*u+v*v);
          if(a>=15) { // draw only if the length >=2.0
            to_draw  =true;
            float r=0.5*(1.0+u/(a+0.1));
            float g=0.5*(1.0+v/(a+0.1));
            float b=0.5*(2.0-(r+g));
            stroke(255*r,255*g,255*b);
           //line(x0,y0,x0+u,y0+v);
          x_y[0][counter] = x0;
          x_y[1][counter] = y0;
          counter ++;
          
           // fill(255);
           // rect(x0,y0,gs,gs);
          }

        }
      }

      // calculate means
      float average_x = 0; 
      float average_y = 0; 
     if(counter >0){ 
     for ( int i = 0; i <= counter; ++i ) 
      { 
      average_x += x_y[0][i]; 
      average_y += x_y[1][i]; 

       } 
      average_x /= (float)(counter); 
      average_y /= (float)(counter);
      // put into noise vector
      myFilter.setFrequency(freq);
      myFilter.setMinCutoff(minCutoff);
      myFilter.setBeta(beta);
      myFilter.setDerivateCutoff(dcutoff);  
      noiseCoord = new PVector(average_x, average_y);
      filteredCoord = myFilter.filterCoord2D(noiseCoord, width, height );
      //println( "filteredCoord = " + filteredCoord );
      average_x = filteredCoord.x;
      average_y = filteredCoord.y;

      noFill();
      
    
      
    if(counter_trace >= rows){
                      saveData();
                      counter_trace = 0;
            } else {
                     pos_x_y[0][counter_trace] = clockNow-saved_time; // time
                     pos_x_y[1][counter_trace] = int(average_x); // x 
                     pos_x_y[2][counter_trace] = int(average_y); // y 
                     counter_trace++;
           }
           
     }
           if(counter_trace > 0){
             int j;
                    for (j = 1; j < counter_trace; j++) {
                      strokeWeight(1.5);
       //               stroke(80,130,160);
                     // stroke(0,255*pos_x_y[1][j-1]/height,255*pos_x_y[2][j-1]/width);
                      stroke(0,180,255);
                      line(pos_x_y[1][j-1], pos_x_y[2][j-1], pos_x_y[1][j], pos_x_y[2][j]);
                    }
                     if(to_draw == true) {
                     fill(255,155,0);
                     stroke(0,255,255);
                     strokeWeight(2);
                     ellipse(pos_x_y[1][j-1],pos_x_y[2][j-1],10,10); 
                     }
                   } 
     

    }

  ///////////////////////////////////////////////////

  fill(255,255,255);
  text(1000/clockDiff + " fps",width-40,height-10); // time (msec) for this frame
  if(flagmovie) text("rec", 40,10);
 
}
 
} // end of draw
 
public void stopGame(){
  minim.stop();
  super.stop();
}
 
public void keyPressed(){
//  if(key=='c') video.settings();
  //if(key=='w') flagseg=!flagseg; // segmentation on/off
  //else if(key=='s') flagsound=!flagsound; //  sound on/off
 // else if(key=='e') stopGame(); // quit
 // else if(key=='m') flagmirror=!flagmirror; // mirror on/off
 // else if(key=='i') flagimage=!flagimage; // show video on/off
  //else if(key=='f') flagflow=!flagflow; // show opticalflow on/off
 // else if(key=='q') {
 //   flagmovie=!flagmovie;
 //   if(flagmovie) { // start recording movie
//      movie = new MovieMaker(this, width, height, "mymovie.mov",
//      fps);
  //  }
  //  else { // stop recording movie
//      movie.finish();
  //  }
 /// }
 
 
}

public void controlEvent(ControlEvent theEvent) {
  //println(theEvent.getController().getName());
  if (theEvent.controller().name().equals("camera_list") == true) {
   println(theEvent.controller().name()+" = "+theEvent.value()); 
   camera_set(int(theEvent.value()));
  }
  n++;
  println("Deleted waypoints");
  for (int i = 0; i < cols; i++) {
  for (int j = 0; j < rows; j++) {
    pos_x_y[i][j] = 0;
    }
  }
  counter_trace = 0;

  
  
}

public void input(String theText) {
  // automatically receives results from controller input
  println("a textfield event for controller 'input' : "+theText);
}
public void camera_detect(){
  
   cameras = Capture.list();
  
  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  } else {
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      println(cameras[i]);
    }
   String[] cameras_split = split(cameras[1], ',');
   println(cameras_split[0]);
   String[] cameras_split2 = split(cameras_split[0], '=');
   println(cameras_split2[1]);
   cam = new Capture(this, wscreen, hscreen,cameras_split2[1], fps);
   cam.start();

}
}

public void camera_set(int a){
  println(a);
  cam.stop();
  //Capture(parent, requestWidth, requestHeight, cameraName, frameRate)
  String[] cameras_split = split(cameras[a], ',');
  String[] cameras_split2 = split(cameras_split[0], '=');
  println(cameras_split2[1]);
  cam = new Capture(this, wscreen, hscreen,cameras_split2[1], fps);
  cam.start();
  save_frame =true;
 
}

void saveData() {  
  counter_files ++;
  // make one String to be saved
  String[] data = new String[counter_trace];
  for (int i = 0; i < counter_trace; i ++ ) {
    // Concatenate variables
    data[i] = pos_x_y[0][i] + "," + pos_x_y[1][i] + ","+ pos_x_y[2][i];

  }
  // Save to File
 // saveStrings("export " + day() + "." + month() + "./" +  "xy_data"  + " " + recname + "_" + counter_files + ".txt", data); 
    saveStrings("export " + day() + "." + month() + "./" + recname + "/" + "txy_data"  + " " + recname + ".txt", data); 
    saveFrame("export " + day() + "." + month() + "./" + recname + "/" + "trace " + day() + "." + month() + "." + " " + recname + ".jpg");
  

  recording_start = false;
  counter_files = 0;
}

// function START will receive changes  
public void START(int theValue) {
  println("a button event from START: "+theValue);
  //recording_length retrieved 
  recording_length = int(cp5.get(Textfield.class,"RECORDING LENGTH [s]").getText());
  recname =  cp5.get(Textfield.class,"NAMEREC").getText();
  println(recname);
  if(recording_length > 2){
  println("Started recording for: " + recording_length + " seconds.");
  sine = new SineWave(640, 0.5, audioout.sampleRate());
  sine.portamento(200);
  sine.setAmp(0.0);
  audioout.addSignal(sine);
  recording_start = true;
  saved_time = millis();
  c.reset();
  }

}
