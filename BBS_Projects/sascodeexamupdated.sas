libname c 'C:\Users\bbsstudent\Desktop\progetto';
proc import datafile="C:\Users\bbsstudent\Desktop\progetto\dineout"
    out=c.dineout
    dbms=xlsx
    replace;
    getnames=yes;
run;

data c.clean;
	set c.dineout 
			(keep = Cooking_effort
				Social_motive
				Quality_v_experience
				Vibe_motive
				Reward_motive
				Tradition_v_modern
				Dining_frequency
				Convenience_motive
			rename = (
				Cooking_effort        = var1
				Social_motive         = var2
				Quality_v_experience  = var3 
				Vibe_motive           = var4
				Reward_motive         = var5
				Tradition_v_modern    = var6
				Dining_frequency      = var7
				Convenience_motive    = var8));
	label var1="var1" var2="var2" var3= "var3" var4="var4" var5="var5" var6="var6" var7="var7" var8="var8";
run;
/*PRELIMINARY ANALYSIS*/
/* 1. Frequency distribution of your variables */
proc freq data=c.clean;
    tables var1-var8;
run;

/* 1. Check the ACTUAL names in your data */
proc contents data=c.dineout; 
run;

/* 2. Re-create c.clean carefully */
data c.clean;
    set c.dineout;
    
    /* Creating vars this way is safer than 'rename' if names are tricky */
    var1 = Cooking_effort;
    var2 = Social_motive;
    var3 = Quality_v_experience;
    var4 = Vibe_motive;
    var5 = Reward_motive;
    var6 = Tradition_v_modern;
    var7 = Dining_frequency;
    var8 = Convenience_motive;

    /* Delete empty rows (common in Excel imports) */
    if var1 = . then delete; 

    keep var1-var8;
run;

/* Correlation of original variables */
proc corr data=c.clean;
run;

/* First PCA to detect Size Effect */
proc princomp data=c.clean out=c.coord;
    var var1-var8;
run;

/* Check if the first component (Prin1) is just the row average */
data c.check_se;
    set c.coord;
    avgi = mean(of var1-var8); /* Average score given by this person */
    mini = min(of var1-var8);
    maxi = max(of var1-var8);
run;

proc corr data=c.check_se;
    var avgi prin1; 
run;
/* If correlation is very high (>0.90), then Prin1 = Size Effect */

data c.sz_dineout; 
    set c.clean;
    /* Get unique ID for merging later */
    id = _N_; 
    
    avgi = mean(of var1-var8);
    mini = min(of var1-var8);
    maxi = max(of var1-var8);
    
    array a var1-var8;
    array b new1-new8;
    
    do i = 1 to 8;
        if a[i] > avgi then b[i] = (a[i] - avgi) / (maxi - avgi);
        else if a[i] < avgi then b[i] = (a[i] - avgi) / (avgi - mini);
        else if a[i] = avgi then b[i] = 0;
        
        /* Handle missing values or cases where person gave all same scores */
        if a[i] = . or (maxi-avgi)=0 or (avgi-mini)=0 then b[i] = 0;
    end;
    
    label new1='Cooking Effort'
          new2='Social Motive'
          new3='Quality v Experience'
          new4='Vibe Motive'
          new5='Reward Motive'
          new6='Tradition v Modern'
          new7='Dining Frequency'
          new8='Convenience Motive';
    drop i;
run;

/* PCA on normalized variables */
proc princomp data=c.sz_dineout out=c.sz_coord;
    var new1-new8;
run;

/* Hierarchical Clustering (Ward's Method) */
proc cluster data=c.sz_coord method=ward out=c.sz_tree;
    var prin1-prin3; /* Usually use first 3 components for clustering */
    id id;
run;

/* Generate Dendrogram */
proc tree data=c.sz_tree;
run;

/* Create the cluster variable (Choosing 4 clusters as an example) */
proc tree data=c.sz_tree noprint out=c.sz_cluster nclusters=4;
    id id;
run;

/* Prepare data for T-Tests */
proc sort data=c.sz_cluster; by id; run;
proc sort data=c.sz_dineout; by id; run;

data c.sz_final;
    merge c.sz_dineout c.sz_cluster;
    by id;
run;

/* Create the 'Fake' dataset for comparison */
data c.sz_comparison;
    set c.sz_final;
    output;         /* Actual unit in its cluster */
    cluster = 99;   /* Add a copy of everyone to a 'Global' cluster */
    output;
run;

/* Macro to run T-Tests for 4 clusters */
%macro profile_clusters;
%do k=1 %to 4;
    proc ttest data=c.sz_comparison;
        where cluster=&k or cluster=99;
        class cluster;
        var new1-new8;
        ods output ttests=c.stats_cl&k (where=(method='Satterthwaite') 
                           rename=(tvalue=t_&k probt=p_&k));
    run;
%end;
%mend;
%profile_clusters;

/* Merge results for a final report table */
data c.report_table;
    merge c.stats_cl1 c.stats_cl2 c.stats_cl3 c.stats_cl4;
    by variable;
run;

proc print data=c.report_table;
    var variable t_1 p_1 t_2 p_2 t_3 p_3 t_4 p_4;
run;
