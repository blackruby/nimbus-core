#include "extconf.h"
#include "ruby/ruby.h"
// #include "ruby/encoding.h"

#include "stdio.h"
#include "string.h"
#include "unistd.h"
#include "sys/stat.h"

char *k;
int ks;

VALUE rb_nimbus_source(VALUE self, VALUE binding) {
  char x = 'a', *buf, *fic, nfic[300], ev[18], fi[9], fm[12];
  int i, seed;
  long length;
  FILE *f;
  VALUE res;
  struct stat fs;

  ev[0]='_'-x;ev[1]='r'-x;ev[2]='u'-x;ev[3]='b'-x;ev[4]='y'-x;ev[5]='_'-x;ev[6]='v'-x;ev[7]='e'-x;ev[8]='r'-x;ev[9]='s'-x;ev[10]='i'-x;ev[11]='o'-x;ev[12]='n'-x;ev[13]='_'-x;ev[14]='i'-x;ev[15]='d'-x;ev[16]='_'-x;ev[17]=0;
  for (i = 0; i < 17; i++) {ev[i] += x;}
  fi[0]='_'-x;fi[1]='_'-x;fi[2]='F'-x;fi[3]='I'-x;fi[4]='L'-x;fi[5]='E'-x;fi[6]='_'-x;fi[7]='_'-x;fi[8]=0;
  for (i = 0; i < 8; i++) {fi[i] += x;}
  fm[0]='.'-x;fm[1]='n'-x;fm[2]='i'-x;fm[3]='m'-x;fm[4]='b'-x;fm[5]='u'-x;fm[6]='s'-x;fm[7]='/'-x;fm[8]='%'-x;fm[9]='j'-x;fm[10]='X'-x;fm[11]=0;
  for (i = 0; i < 11; i++) {fm[i] += x;}

  res = rb_funcall(binding, rb_intern(ev), 1, rb_str_new_cstr(fi));
  fic = StringValueCStr(res);
  stat(fic, &fs);
  sprintf(nfic, fm, (uintmax_t)fs.st_ino + 123456789);

  f = fopen (nfic, "rb");
  if (!f) return(Qnil);

  fseek(f, 0, SEEK_END);
  length = ftell(f);
  fseek(f, 0, SEEK_SET);
  buf = malloc(length + 1);
  fread(buf, 1, length, f);
  fclose(f);
  buf[length] = 0;

  seed = fs.st_ino % ks;
  for (i = 0; i < length; i++) {
    buf[i] = (buf[i] - k[seed] + 256) % 256;
    seed = (seed + 1) % ks;
  }

  res = rb_str_new_cstr(buf);
  res = rb_funcall(res, rb_intern("force_encoding"), 1, rb_str_new_cstr("UTF-8"));
  rb_funcall(binding, rb_intern(ev), 1, res);
  free(buf);

  return(Qnil);
}

void Init_nimbus()
{
  char x = 'a', ce[11], al[29], ns[14];
  int i;

  ce[10]=0;ce[0]='c'-x;ce[1]='l'-x;ce[2]='a'-x;ce[3]='s'-x;ce[4]='s'-x;ce[5]='_'-x;ce[6]='e'-x;ce[7]='v'-x;ce[8]='a'-x;ce[9]='l'-x;
  for (i = 0; i < 10; i++) ce[i] += x;

  al[28]=0;al[0]='a'-x;al[1]='l'-x;al[2]='i'-x;al[3]='a'-x;al[4]='s'-x;al[5]=' '-x;al[6]='_'-x;al[7]='r'-x;al[8]='u'-x;al[9]='b'-x;al[10]='y'-x;al[11]='_'-x;al[12]='v'-x;al[13]='e'-x;al[14]='r'-x;al[15]='s'-x;al[16]='i'-x;al[17]='o'-x;al[18]='n'-x;al[19]='_'-x;al[20]='i'-x;al[21]='d'-x;al[22]='_'-x;al[23]=' '-x;al[24]='e'-x;al[25]='v'-x;al[26]='a'-x;al[27]='l'-x;
  for (i = 0; i < 28; i++) al[i] += x;

  ns[13]=0;ns[0]='n'-x;ns[1]='i'-x;ns[2]='m'-x;ns[3]='b'-x;ns[4]='u'-x;ns[5]='s'-x;ns[6]='_'-x;ns[7]='s'-x;ns[8]='o'-x;ns[9]='u'-x;ns[10]='r'-x;ns[11]='c'-x;ns[12]='e'-x;
  for (i = 0; i < 13; i++) ns[i] += x;

  rb_funcall(rb_cBinding, rb_intern(ce), 1, rb_str_new_cstr(al));
  rb_define_global_function(ns, rb_nimbus_source, 1);
  /*-*/
}
