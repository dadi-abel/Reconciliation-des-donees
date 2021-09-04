/*TO UPDATE to declare library of SAS DATASETS*/

/*LIBNAME AB15003 "H:\AB15003\01_Data Bases\01_LS_Prod\20210420";*/


/*>>>>>>>>>>IWRS IMPORT >>>>>>>*/ LIBNAME xls EXCEL "H:\AB15003\01_Data Bases\02_IWRS\AB15003_Patients information Copy.xls" ; 

DATA IWRS;
	SET xls."Patients information - Detail$"n;
RUN;
PROC SORT DATA=IWRS OUT= IWRS; BY Patient_number; RUN;

DATA IWRS;
	SET IWRS;
	Findings_value = input (Findings_value, $15.);/*TRANSFORME YEAR OF BIRTH TO NUMERIC FORM*/
RUN;

/********************************************************************************/
/*******************************************************************************/
/******************************************************************************/
DATA IFC;
	SET AB15003.rep_ifc_dm;
	FORMAT Year_Birth_D 10.;
	Year_Birth = scan(DOB,3,'-');
	Year_Birth_D = input (Year_Birth, 10.);/*TRANSFORME YEAR OF BIRTH TO NUMERIC FORM*/
	DOB_COMPRES = compress(DOB,'-');/*REMOVE THE ASH*/
	Date_Birth = input (DOB_COMPRES, date9.);
	FORMAT Date_Birth date9.;
	DROP DOB_COMPRES;
RUN;


/*CREATE A VARIABLE YEAR OF BIRTH FROM TWO VARIABLES CONTAINING YEARS OF BIRTH FROM THE IFC TABLE*/
PROC SQL;
	CREATE TABLE IFC1 AS
	SELECT a.SITEID, a.SUBJID, a.SEX, a.Date_Birth, 
	                        case        WHEN Year_Birth_D <> . THEN Year_Birth_D
	                                    WHEN BRTHYY <> . THEN BRTHYY
	                        end AS YEAR_BTH
	FROM IFC a
	ORDER BY SUBJID; /*SORT THE DATASET*/
QUIT;

/**/
DATA REP_VS_SCREENING (KEEP=SUBJID SUBJEVENTNAME_SCREENING HEIGHT);
	SET AB15003.REP_VS;
	WHERE SUBJEVENTNAME = "Screening";
	RENAME SUBJEVENTNAME = SUBJEVENTNAME_SCREENING;
RUN;
PROC SORT DATA=REP_VS_SCREENING; BY SUBJID; RUN;

DATA REP_VS_BASELINE (KEEP=SUBJID SUBJEVENTNAME_BASELINE WEIGHT BMI);
	SET AB15003.REP_VS;
	WHERE SUBJEVENTNAME = "Baseline";
	RENAME SUBJEVENTNAME = SUBJEVENTNAME_BASELINE;
RUN;
PROC SORT DATA=REP_VS_BASELINE; BY SUBJID; RUN;

/*MERGE REP_VS_SCREENING AND REP_VS_BASELINE*/
DATA REP_VS(KEEP=SUBJID HEIGHT WEIGHT BMI);
	SET REP_VS_SCREENING;
	MERGE REP_VS_BASELINE;
	BY SUBJID;
RUN;
PROC SORT DATA=REP_VS; BY SUBJID; RUN;

/**/
DATA REP_PRURITUS (KEEP=SUBJID SUBJEVENTNAME PRURSCOR);
	SET AB15003.REP_PRURITUS;
	WHERE SUBJEVENTNAME = "Baseline";
RUN;
PROC SORT DATA=REP_PRURITUS; BY SUBJID; RUN;

/**/
DATA REP_HAMD (KEEP=SUBJID SUBJEVENTNAME QSORRES); 
	SET AB15003.REP_HAMD;
	WHERE SUBJEVENTNAME = "Baseline";
RUN;
PROC SORT DATA=REP_HAMD; BY SUBJID; RUN;

/**/
DATA REP_FSS (KEEP=SUBJID SUBJEVENTNAME QSFSSSCR);
	SET AB15003.REP_FSS;
	WHERE SUBJEVENTNAME = "Baseline";
RUN;
PROC SORT DATA=REP_FSS; BY SUBJID; RUN;

/**/
DATA REP_FLUSHES (KEEP=SUBJID SUBJEVENTNAME QSFLUSHORRES);
	SET AB15003.REP_FLUSHES;
	WHERE SUBJEVENTNAME = "Baseline";
RUN;
PROC SORT DATA=REP_FLUSHES; BY SUBJID; RUN;

/*CREATION OF A NEW TABLE BY MERGING THE TABLES PREVIOUS SORT KEEPING SOME TARGET VARIABLE FOR RECONCIALIATION*/
DATA NEWDATA;
	LENGTH Patient_number $15.;
	MERGE IWRS 
	IFC1 (RENAME=(SUBJID=Patient_number))
	REP_VS (RENAME=(SUBJID=Patient_number))
	REP_PRURITUS (RENAME=(SUBJID=Patient_number))
	REP_HAMD (RENAME=(SUBJID=Patient_number))
	REP_FSS (RENAME=(SUBJID=Patient_number))
	REP_FLUSHES (RENAME=(SUBJID=Patient_number));
	BY Patient_number;
	KEEP Country_name Center_number Patient_number Visit Findings_name Findings_value SEX 
	Date_Birth YEAR_BTH HEIGHT WEIGHT BMI PRURSCOR QSORRES QSFSSSCR QSFLUSHORRES;
RUN;
PROC SORT data=NEWDATA; BY Patient_number; RUN ;

/********************************************************************************/
/**********************************SEX******************************************/
/******************************************************************************/

PROC SQL;
	CREATE TABLE TAB_SEX AS
	SELECT Country_name, Center_number, Patient_number, Findings_name, Findings_value,SEX 
	FROM NEWDATA
	WHERE Findings_name = "gender"
	ORDER BY Patient_number;
QUIT;

PROC SQL;
	CREATE TABLE TAB_SEX1 AS
	SELECT DISTINCT Country_name, Center_number, Patient_number, Findings_name, Findings_value, SEX,
	                        case     WHEN Findings_value = SUBSTR(SEX,1,1) THEN "COHERENT"
									 WHEN Findings_value NE "" AND SEX = "" THEN ""
									 WHEN Findings_value NE SUBSTR(SEX,1,1) THEN "INCOHERENT"
	                        end AS TEST_SEX
	
	FROM TAB_SEX 
	ORDER BY Patient_number;
QUIT;

/********************************************************************************/
/**********************************WEIGHT***************************************/
/******************************************************************************/ 

PROC SQL;
	CREATE TABLE TAB_WEIGHT AS
	SELECT Country_name,Visit, Center_number, Patient_number, Findings_name, Findings_value,WEIGHT
	FROM NEWDATA
	WHERE Findings_name = "weight" AND Visit = "RANDOMISATION";
QUIT;

/*CONVERTING THE WEIGHT INTO INTEGER*/
DATA TAB_WEIGHT_C ;
	SET TAB_WEIGHT;
	Findings_value1 = INPUT(( SCAN(Findings_value,1,',')),NLNUM10.2);
RUN;

PROC SQL;
	CREATE TABLE TAB_WEIGHT1 AS
	SELECT DISTINCT Country_name, Center_number, Patient_number, Findings_name, Findings_value1,WEIGHT,
	                        case    WHEN (Findings_value1 BETWEEN (WEIGHT-1) AND (WEIGHT+1))
									THEN "COHERENT"
									WHEN Findings_value1 <>. AND WEIGHT =.  
									THEN ""
									WHEN (Findings_value1 NOT BETWEEN (WEIGHT-1) AND (WEIGHT+1))
									THEN "INCOHERENT"
	                        end AS TEST_WEIGHT
	FROM TAB_WEIGHT_C 
	ORDER BY Patient_number;
QUIT;

/********************************************************************************/
/**********************************HEIGHT***************************************/
/******************************************************************************/ 

PROC SQL;
	CREATE TABLE TAB_HEIGHT AS
	SELECT Country_name,Visit, Center_number, Patient_number, Findings_name, Findings_value, HEIGHT
	FROM NEWDATA
	WHERE Findings_name = "height" AND Visit = "RANDOMISATION";
QUIT;

/*CONVERTING THE WEIGHT INTO INTEGER*/

DATA TAB_HEIGHT_C ;
	SET TAB_HEIGHT;
	Findings_value1 = INPUT(TRANWRD(Findings_value,',','.'),COMMA5.);/*REPLACE LE COMMA BY A DIOT*/
	HEIGHT_C = HEIGHT/100; /*CONVERT HEIGHT TO METER*/
RUN;

PROC SQL;
	CREATE TABLE TAB_HEIGHT1 AS
	SELECT DISTINCT Country_name, Center_number, Patient_number, Findings_name, Findings_value1,HEIGHT_C,
	                        case    WHEN (Findings_value1 BETWEEN (HEIGHT_C-1) AND (HEIGHT_C+1))
									THEN "COHERENT"
									WHEN Findings_value1 <>. AND HEIGHT_C =.  
									THEN ""
									WHEN (Findings_value1 NOT BETWEEN (HEIGHT_C-1) AND (HEIGHT_C+1))
									THEN "INCOHERENT"
	                        end AS TEST_HEIGHT
	FROM TAB_HEIGHT_C 
	ORDER BY Patient_number;
QUIT;

/********************************************************************************/
/**********************************DATH OF BIRTH********************************/
/******************************************************************************/ 

PROC SQL;
	CREATE TABLE TAB_BIRTHDATE AS
	SELECT Country_name,Visit, Center_number, Patient_number, Findings_name, Findings_value, Date_Birth, YEAR_BTH
	FROM NEWDATA
	WHERE Findings_name = "birthdate" AND Visit = "RANDOMISATION";
QUIT;

/*CONVERTING THE WEIGHT INTO INTEGER*/
DATA TAB_BIRTHDATE_C ;
	SET TAB_BIRTHDATE;
	Findings_value1 = INPUT(Findings_value,YYMMDD10.);
	FORMAT Findings_value1 DATE9.;
RUN;

PROC SQL;
	CREATE TABLE TAB_BIRTHDATE1 AS
	SELECT DISTINCT Country_name, Center_number, Patient_number, Findings_name, Findings_value1,Date_Birth,YEAR_BTH,
	                        case    WHEN Findings_value1 = Date_Birth 
									OR INPUT(SUBSTR(Findings_value,1,4),BEST4.)= YEAR_BTH
									THEN "COHERENT"
									WHEN Findings_value1 <>. AND (Date_Birth =. OR YEAR_BTH =.)
									THEN ""
									WHEN Findings_value1 <> Date_Birth 
									OR INPUT(SUBSTR(Findings_value,1,4),BEST4.)<> YEAR_BTH
									THEN "INCOHERENT"
	                        end AS TEST_HBIRTHDATE
	FROM TAB_BIRTHDATE_C 
	ORDER BY Patient_number;
QUIT; 

/********************************************************************************/
/**********************************BMI******************************************/
/******************************************************************************/ 

PROC SQL;
	CREATE TABLE TAB_BMI AS
	SELECT Country_name,Visit, Center_number, Patient_number, Findings_name, Findings_value,BMI
	FROM NEWDATA
	WHERE Findings_name = "bmi" AND Visit = "RANDOMISATION";
QUIT;

DATA TAB_BMI_C ;
	SET TAB_BMI;
	Findings_value1 = INPUT(TRANWRD(Findings_value,',','.'),COMMA5.);/*REPLACE LE COMMA BY A DIOT AND CONVERT TO NUMERIC*/
RUN;

PROC SQL;
	CREATE TABLE TAB_BMI_1 AS
	SELECT DISTINCT Country_name, Center_number, Patient_number, Findings_name, Findings_value1,BMI,
	                        case    WHEN (Findings_value1 BETWEEN (BMI-1) AND (BMI+1))
									THEN "COHERENT"
									WHEN Findings_value1 <>. AND BMI =.  
									THEN ""
									WHEN (Findings_value1 NOT BETWEEN (BMI-1) AND (BMI+1))
									THEN "INCOHERENT"
	                        end AS TEST_BMI
	FROM TAB_BMI_C 
	ORDER BY Patient_number;
QUIT;

/********************************************************************************/
/**********************************PRURITUS SCORE*******************************/
/******************************************************************************/ 

PROC SQL;
	CREATE TABLE TAB_PRURITUS AS
	SELECT Country_name,Visit, Center_number, Patient_number, Findings_name, Findings_value,PRURSCOR
	FROM NEWDATA
	WHERE Findings_name = "Pruritus" AND Visit = "RANDOMISATION";
QUIT;

DATA TAB_PRURITUS_C ;
	SET TAB_PRURITUS;
	Findings_value1 = INPUT(TRANWRD(Findings_value,',','.'),COMMA5.);/*REPLACE LE COMMA BY A DOT*/
RUN;

PROC SQL;
	CREATE TABLE TAB_PRURITUS1 AS
	SELECT DISTINCT Country_name, Center_number, Patient_number, Findings_name, Findings_value1,PRURSCOR,
	                        case    WHEN (Findings_value1 BETWEEN (PRURSCOR-1) AND (PRURSCOR+1))
									THEN "COHERENT"
									WHEN Findings_value1 <>. AND PRURSCOR =.  
									THEN ""
									WHEN (Findings_value1 NOT BETWEEN (PRURSCOR-1) AND (PRURSCOR+1))
									THEN "INCOHERENT"
	                        end AS TEST_PRURSCOR
	FROM TAB_PRURITUS_C 
	ORDER BY Patient_number;
QUIT;

/********************************************************************************/
/********************************HAMILTON RATING SCALE**************************/
/******************************************************************************/ 

PROC SQL;
	CREATE TABLE TAB_HAM AS
	SELECT Country_name,Visit, Center_number, Patient_number, Findings_name, Findings_value,QSORRES
	FROM NEWDATA
	WHERE Findings_name = "Ham" AND Visit = "RANDOMISATION";
QUIT;

DATA TAB_HAM_C ;
	SET TAB_HAM;
	Findings_value1 = INPUT(TRANWRD(Findings_value,',','.'),COMMA5.);/*REPLACE LE COMMA BY A DOT*/
RUN;

PROC SQL;
	CREATE TABLE TAB_HAM_1 AS
	SELECT DISTINCT Country_name, Center_number, Patient_number, Findings_name, Findings_value1,QSORRES,
	                        case    WHEN (Findings_value1 BETWEEN (QSORRES-1) AND (QSORRES+1))
									THEN "COHERENT"
									WHEN Findings_value1 <>. AND QSORRES =.  
									THEN ""
									WHEN (Findings_value1 NOT BETWEEN (QSORRES-1) AND (QSORRES+1))
									THEN "INCOHERENT"
	                        end AS TEST_QSORRES
	FROM TAB_HAM_C 
	ORDER BY Patient_number;
QUIT;

/********************************************************************************/
/**************************FATIGUE SEVERITY SCALE*******************************/
/******************************************************************************/ 

PROC SQL;
	CREATE TABLE TAB_FSS AS
	SELECT Country_name,Visit, Center_number, Patient_number, Findings_name, Findings_value,QSFSSSCR
	FROM NEWDATA
	WHERE Findings_name = "FSS" AND Visit = "RANDOMISATION";
QUIT;

DATA TAB_FSS_C ;
	SET TAB_FSS;
	Findings_value1 = INPUT(TRANWRD(Findings_value,',','.'),COMMA5.);/*REPLACE LE COMMA BY A DOT*/
RUN;

PROC SQL;
	CREATE TABLE TAB_FSS_1 AS
	SELECT DISTINCT Country_name, Center_number, Patient_number, Findings_name, Findings_value1,QSFSSSCR,
	                        case    WHEN (Findings_value1 BETWEEN (QSFSSSCR-1) AND (QSFSSSCR+1))
									THEN "COHERENT"
									WHEN Findings_value1 <>. AND QSFSSSCR =.  
									THEN ""
									WHEN (Findings_value1 NOT BETWEEN (QSFSSSCR-1) AND (QSFSSSCR+1))
									THEN "INCOHERENT"
	                        end AS TEST_QSFSSSCR
	FROM TAB_FSS_C 
	ORDER BY Patient_number;
QUIT;

/********************************************************************************/
/*****************************NUMBER OF FLUSHES*********************************/
/******************************************************************************/ 

PROC SQL;
	CREATE TABLE TAB_FLUSHES AS
	SELECT Country_name,Visit, Center_number, Patient_number, Findings_name, Findings_value,QSFLUSHORRES
	FROM NEWDATA
	WHERE Findings_name = "Flushes" AND Visit = "RANDOMISATION";
QUIT;

DATA TAB_FLUSHES_C ;
	SET TAB_FLUSHES;
	Findings_value1 = INPUT(TRANWRD(Findings_value,',','.'),COMMA5.);/*REPLACE LE COMMA BY A DOT*/
RUN;

PROC SQL;
	CREATE TABLE TAB_FLUSHES_1 AS
	SELECT DISTINCT Country_name, Center_number, Patient_number, Findings_name, Findings_value1,QSFLUSHORRES,
	                        case    WHEN (Findings_value1 BETWEEN (QSFLUSHORRES-1) AND (QSFLUSHORRES+1))
									THEN "COHERENT"
									WHEN Findings_value1 <>. AND QSFLUSHORRES =.  
									THEN ""
									WHEN (Findings_value1 NOT BETWEEN (QSFLUSHORRES-1) AND (QSFLUSHORRES+1))
									THEN "INCOHERENT"
	                        end AS TEST_QSFLUSHORRES
	FROM TAB_FLUSHES_C 
	ORDER BY Patient_number;
QUIT;


