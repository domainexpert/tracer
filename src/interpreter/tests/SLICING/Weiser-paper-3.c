/******************************************************************/
/* This program is adapted to C from Weiser'84 "Program Slicing"  */
/******************************************************************/

int main(int c, int k, int c1, int k1, int c2, int k2){
  int a ,b ,x ,y ,z;
  int a1,b1,x1,y1,z1;
  int a2,b2,x2,y2,z2;
  int X1,X2,X3;

  a = 5;                /* IN */
  while ( k < 100){     /* IN */
    if (c < 7){         /* IN */
      b = a;            /* IN */
      x = 1;            /* IN */
    }
    else{
      c = b;            /* IN */
      y = 2;            /* IN */
      //if(X1) break;
    }
    k = k + 1;          /* IN */
    
    //////////////////////////////////
    a1 = 5;             /* IN */
    while ( k1 < 100){  /* IN */
      if (c1 < 7){      /* IN */
	b1 = a1;        /* IN */
	x1 = 1;         /* IN */
      }
      else{
	c1 = b1;        /* IN */
	y1 = 2;         /* IN */
	//if(X2) break;
      }
/*       ////////////////////////////////// */
/*       a2 = 5;             /\* IN *\/ */
/*       while ( k2 < 100){  /\* IN *\/ */
/* 	if (c2 < 7){      /\* IN *\/ */
/* 	  b2 = a2;        /\* IN *\/ */
/* 	  x2 = 1;         /\* IN *\/ */
/* 	} */
/* 	else{ */
/* 	  c2 = b2;        /\* IN *\/ */
/* 	  y2 = 2;         /\* IN *\/ */
/* 	  //if(X1) break; */
/* 	} */
/* 	k2 = k2 + 1;      /\* IN *\/ */
/*       } */
/*       z2 = x2 + y2 ;      /\* IN *\/     */
/*       ////////////////////////////////// */
      k1 = k1 + 1;      /* IN */
    }
    z1 = x1 + y1 ;      /* IN */    
    //////////////////////////////////    
  }
  z = x + y ;           /* IN */  
  return z1;            /* OUT */  

  _SLICE(z,z1 /*,z2*/);
}


