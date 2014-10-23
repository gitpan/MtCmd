/*************************************************************************
*                                                                        *
* � Copyright IBM Corporation 2007 All rights reserved.                  *
*                                                                        *
* This program and the accompanying materials are made available under   *
* the terms of the Common Public License v1.0 which accompanies this     *
* distribution, and is also available at http://www.opensource.org       *
*                                                                        *
* Contributors:                                                          *
*                                                                        *
* William Spurlin - Creation and framework                               *
*                                                                        *
*                                                                        *
*************************************************************************/

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include "proc_table.h"
#if defined ATRIA_WIN32_COMMON 
#include <stdio.h>
#include <stdlib.h>
#endif


static int
not_here(s)
char *s;
{
    croak("%s not implemented on this architecture", s);
    return -1;
}

void
blok_init (BLOK *blokP)
{
    blokP->buffSize = BLOK_START_SIZE;
    blokP->currSize = 0;
    blokP->buffP = (char *) malloc (blokP->buffSize);
}

void
blok_reset (BLOK *blokP)
{
    *blokP->buffP = '\0';
    blokP->currSize = 0;
}

void
blok_done (BLOK *blokP)        
{
    free (blokP->buffP);
}

void
silent (void *argP, char *strP)
{
    ;
}

void
cmdout (void *argP, char *strP)
{
    BLOK *blokP;
    int len;
    blokP = (BLOK *) argP;
    len = strlen (strP);
    if (blokP->currSize + len + 1 > blokP->buffSize) {
        blokP->buffSize = blokP->currSize + len + 1;
        blokP->buffP = (char *) realloc (blokP->buffP, blokP->buffSize);
    }
    strcat (blokP->buffP, strP);
    blokP->currSize += len;
}

int
dispatched_syn_call (char *cmdP, BLOK *outP, BLOK *errP, gen_t area, gen_t * a_cmdsyn_cmdflags, gen_2_t * a_cmdsyn_proc_table)
{
    void (*out_rtn) (void*, char*), (*err_rtn) (void*, char*);
/* is standard out wanted? */
    if (outP == STANDARD)
        out_rtn = NULL;
    else if (outP == DEVNULL)
        out_rtn = silent;
    else {
        blok_reset (outP);
        out_rtn = cmdout;
    }
/* is standard err wanted? */
    if (errP == STANDARD)
        err_rtn = NULL;
    else if (errP == DEVNULL)
        err_rtn = silent;
    else {
        blok_reset (errP);
        err_rtn = cmdout;
    }
    imsg_set_app_name("ClearCase::MtCmd");
    imsg_redirect_output (out_rtn, outP, err_rtn, errP);
    return (cmdsyn_exec_dispatch (cmdP, area,a_cmdsyn_cmdflags,a_cmdsyn_proc_table) == T_OK);
}

int
dispatched_synv_call (int argc, char * argv[], BLOK *outP, BLOK *errP, gen_t area, gen_t * a_cmdsyn_cmdflags, gen_2_t * a_cmdsyn_proc_table)
{
    void (*out_rtn) (void*, char*), (*err_rtn) (void*, char*);
/* is standard out wanted? */

    if (outP == STANDARD)
        out_rtn = NULL;
    else if (outP == DEVNULL)
        out_rtn = silent;
    else {
        blok_reset (outP);
        out_rtn = cmdout;
    }
/* is standard err wanted? */
    if (errP == STANDARD)
        err_rtn = NULL;
    else if (errP == DEVNULL)
        err_rtn = silent;
    else {
        blok_reset (errP);
        err_rtn = cmdout;
    }
    imsg_set_app_name("ClearCase::MtCmd");
    imsg_redirect_output (out_rtn, outP, err_rtn, errP);
    return 
	(
	    cmdsyn_execv_dispatch (
		argc,
		argv, 
		area,
		a_cmdsyn_cmdflags,
		a_cmdsyn_proc_table
	    ) == 
	    T_OK
	);
}

int status;

MODULE = ClearCase::MtCmd		PACKAGE = ClearCase::MtCmd	PREFIX=cmd_	
PROTOTYPES: ENABLE

int
unsetview(...)
  CODE:
	int n_ok = 0;
	if (items > 0) { 
		if(sv_isobject(ST(0)) && items == 1) {
 			/* OK */
		}
		else {
 			fprintf(stderr,"WARNING: View was not unset. Usage: unsetview()\n");
			 n_ok = 1;
		}
		
	};
	if (n_ok) {
		RETVAL = 1;
	} else {
#ifndef ATRIA_WIN32_COMMON
             RETVAL = view_set_current_view(NULL);
#else
             fprintf(stderr,"ERROR: unsetview() not available in Win32\n");
             RETVAL = 1;
#endif 
	}
  OUTPUT:
	RETVAL

int
cmdstat()
  CODE:
	RETVAL = status;
  OUTPUT:
	RETVAL

int
exec(...)
  PPCODE:
	int gimme = GIMME_V;
	int debug = 0;
	int is_object;
	SV* sv;
	HV* myhash;
	SV** out_p;
	SV** err_p;
	BLOK out;
        BLOK err;
	BLOK * blok_out_p;
	BLOK * blok_err_p;
	gen_t area =  stg_create_area ( 2048 );
#ifdef ATRIA_WIN32_COMMON
  WORD VersionRequested;
  WSADATA wsaData;
  int myerr;
#endif
        int StdOut = 1;
	int StdErr = 1;
	int i = 1;
	int offset=1;
    	const char *pkg_p = (char *)SvPV(ST(0),PL_na);
	int argc = items + 1;
	char ** argv;
	blok_init (&out);
	blok_out_p = &out;
  	blok_init (&err);
	blok_err_p = &err;
	if(sv_isobject(ST(0))){
		is_object=1;
		myhash = (HV*)SvRV(ST(0));
		out_p = hv_fetch(myhash, "debug", 5, 0);
		if(out_p == NULL ){}
		else{ debug = (int)SvIV(*out_p);}
		argc--;
		offset--;
		if(debug){
			printf("Object\t%s\n",pkg_p);
			if (sv_derived_from(ST(0), "ClearCase::MtCmd")) { 
			    printf("Derived from ClearCase::MtCmd\n"); 
			}
		}
	}



	if ( sv_isa(ST(0), "ClearCase::MtCmd") || 
	     sv_derived_from(ST(0), "ClearCase::MtCmd") ){
		out_p = hv_fetch(myhash, "outfunc", 7, 0);
		err_p = hv_fetch(myhash, "errfunc", 7, 0);
		if(out_p == NULL ){}
		else{   
		    StdOut=(int)SvIV(*out_p); 
		    if (StdOut == 0){
			blok_out_p = STANDARD;
		    }else{ 
			StdOut = 1;
		    }
 		}
		if(err_p == NULL ){}
		else{   
		    StdErr=(int)SvIV(*err_p); 
		    if (StdErr == 0){blok_err_p = STANDARD;}else{ StdErr = 1;}
 		}
	}else{
		if(debug){
		    printf("pkg_p: Not ClearCase::MtCmd: %s\n",
			   (char *)pkg_p);
		}
		is_object=0;
		/* XXX Not a ClearCase::MtCmd.  What to do? */
	}
	argv  = (char**)malloc(argc*sizeof(char *));
	argv[0]=NULL;
	for(;i < argc; i++){
		argv[i] = (char *)SvPV(ST(i - offset), PL_na);
		if(debug){printf("argv[%d]\t%s\n",i,argv[i]);}
	};
#ifdef ATRIA_WIN32_COMMON
        VersionRequested = MAKEWORD( 2, 2 );
        myerr = WSAStartup( VersionRequested, &wsaData );
        if( myerr != 0 ){
	    fprintf(stderr,
		    "we could not find a usable WinSock DLL\n");
        return;
        }
#endif
	pfm_init ();
	vob_ob_all_cache_action(NULL,1,1);
	if(argc == 2){   /* There is only one argument.  Treat it as a string. */
	    status = dispatched_syn_call (
		argv[1],
		blok_out_p, 
		blok_err_p, 
		area,
		ms_cmdsyn_get_cmdflags(),
		ms_cmdsyn_proc_table
	    );
        }else{
	    status = dispatched_synv_call (
		argc,
		argv, 
		blok_out_p, 
		blok_err_p, 
		area,
		ms_cmdsyn_get_cmdflags(),
		ms_cmdsyn_proc_table
	    );	    
	}  
	status = status ? 0 : 1;
	if(is_object && hv_exists(myhash,"status",6)){
		out_p = hv_fetch(myhash,"status",6,0);
		sv_setiv(*out_p, status);
	}
	vob_ob_all_cache_action(NULL,3,0);
	free(argv);
	stg_free_area(area,TRUE);
	EXTEND(sp,1);	
	if (gimme == G_SCALAR){
		if(status){
			if(StdErr){PUSHs(sv_2mortal(newSVpv(err.buffP,0)));}else{}
		}else{
			if(StdOut){PUSHs(sv_2mortal(newSVpv(out.buffP,0)));}else{}
		}
	}else{
        	PUSHs(sv_2mortal(newSViv(status)));
		if(StdOut){
			EXTEND(sp,1);	
	        	PUSHs(sv_2mortal(newSVpv(out.buffP,0)));
		}else{}
		if(StdErr){
			EXTEND(sp,1);	
        		PUSHs(sv_2mortal(newSVpv(err.buffP,0)));
		}else{}
	}
	blok_done(&out);
        blok_done(&err);



