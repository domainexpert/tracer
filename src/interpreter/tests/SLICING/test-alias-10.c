int *ptr1,*ptr2,*result;
int x,y,z,p,q;

void main(int N){
  int i;
  i = 0;          /*IN */       
   
  while (i < N){  /*IN*/
    if (p>0)      /*IN*/       
      ptr1 = &y;  /*IN*/
    else          /*OUT*/       
      ptr2 = &x;  /*OUT*/  

    if (q>0)      /*OUT*/       
      *ptr1 = z;  /*OUT*/
    else          /*OUT*/       
      *ptr2 = z;  /*OUT*/  
    
    i++;          /*IN*/
  }
  result = ptr1;  /*IN*/  
  return;
  _SLICE(result);
}

