# Projection 

icheck = T #to collect the sums at each stage (sx_propedu, mig,migC,migfinal,)
id.cols = c("Time","region","sex","agest","edu") #also used during the projection
iper = initime

#main result file
popdt[is.na(pop),pop:=0]

final1 = copy(popdt)[,`:=`(births=0,
                          pop1=0, #final pop
                          idom=0,
                          odom=0,
                          emi=0,
                          imm=0,
                          edutran=0,
                          deaths=0)]
#check [see non-negative values for 0-80]
final1[Time==2022,by=.(agest),sum(pop)]

final1[Time==2022,sum(pop)]
# 203,080,756
final1[Time==2022,by=.(edu,agest),sum(pop)] %>% spread(edu,V1)
#clean the path_scen
unlink(dir(path_scen,full.names = T))

#check again

ireg = regions;{ #to run for all regions at the same time
# for(ireg in regions) {
   
  iper = 2022
  # iper = iper+5
   print("Until 2062")
  for (iper in seq(initime,fintime-ts,ts))
     {
    print(iper)
    
    
    #adult sx and edu
    {#sx and edu
    #pop1
      
    final.temp = copy(final1)[Time == iper&region%in%ireg]# chose an many regions you want
    
    
    # final.temp[,sum(pop),by=.(agest,edu)]%>%spread(edu,V1)
    # final.temp[,sum(pop)]
    
    #this way sx is not saved as a separate file [births -5 is empty]
    # final.temp[is.nan(pop),pop:=0.001] #??check this out
    # sxdt[region==11&Time==2022&sex=="m"&agest==10]%>%spread(edu,sx)

    final.temp <- final.temp[sxdt,on=id.cols,`:=`(sx=sx,pop1=pop*sx,deaths=pop*(1-sx))]
    # final.temp[,sum(deaths)] #6,303,396 2010-2015 deaths
    # final.temp[is.na(pop1)]
    if(iper < 2025) print("take care of sx edu") #we have to apply overall sx for under 15
    # final.temp[pop1 < 0 ]
    #eduprop [new transitions]
    
    # time and age as initime+5, corrected to match initime
    #ieduprop <- copy(propdt)[Time==iper+5 & region%in%ireg][
    #  ,`:=`(Time=Time-5,agest=agest-5)][prop<0,prop:=0.001][
    #  ,.(edu=edu,prop=prop.table(prop)),by=setdiff(id.cols,"edu")]
    ieduprop <- copy(propdt)[Time==iper+5 & region%in%ireg][
      ,`:=`(Time=Time-5,agest=agest-5)][prop<0,prop:=0.001][
      ,.(edu=edu,prop=prop.table(prop)),by=setdiff(id.cols,"edu")]

    #check
    # ieduprop[,by=.(region,sex,agest),sum(prop)][,V1]
    # ieduprop%>%spread(edu,prop) %>% mutate(sum = rowSums(.[5:10]))
    
     # xx <- final.temp[sex=="f"&agest==15,.(edu,pop)][,prop:=prop.table(.SD$pop)]
    
    #agr pop 
    pop1agr <- copy(final.temp)[agest%in%10:25][,.(pop1=sum(pop1)),by=setdiff(id.cols,"edu")]
    pop1agr[,sum(pop1)]#66,454,709
    #merge
    ieduprop[pop1agr,on=setdiff(id.cols,"edu"),`:=`(pop1=pop1*prop)]
    ieduprop[,sum(pop1)]#66,454,709
    
    #check (0.9999??)
    #bring pop1edu into pop1 (update)    
    final.temp[ieduprop,on=id.cols,`:=`(pop1=i.pop1,
                                        edutran = pop1-i.pop1)]
    vars = names(final.temp)[6:15]#for checking
    rm(ieduprop,pop1agr)
    }

  #check (edutran = 0)
     if(icheck){ 
       final.summ <-final.temp[,lapply(.SD,sum),.SDcols = vars,by=.(Time)][,pop1:=pop+births-deaths][,stage:="sx_eduprop"]
        print(final.summ)
        print(final.summ)
        
        print("35")
        final.reg.summ <-final.temp[region=="35",lapply(.SD,sum),.SDcols = vars,by=.(Time)
                                    ][,pop1:=pop+births-deaths][,stage:="sx_eduprop"]
        print(final.reg.summ)
        print(final.reg.summ)
        
       }
    # Time       pop births      pop1 idom odom emi imm       edutran  deaths       sx      stage
    # 1: 2010 190755799      0 185052047    0    0   0   0 -1.442459e-09 5703752 5733.327 sx_eduprop
    
    
    
    
  #emig0 means use given education-specific migration rate
  #Here in any case - we need to adjust for scenarios + net0 
  if(grepl("emig",iscen_text)){
    final.temp[copy(emrdt)[,agest:=agest-5], #2020-2025, age at 2025, so to match with pop1 (with age at 2015)
               on=.(Time,region,sex,edu,agest),`:=`(emr=i.emr,emi=pop1*i.emr)]#end of the period (to be applied, age is not there)
  }   
 
  if(grepl("_dom",iscen_text)){
       #Bilateral implementation
    #-5 to be added to newborns
    # stop("xxxa;'dsflkj")   
    pop.origin = copy(final.temp)[agest>=5&agest<=90,.(region,Time,sex,edu,agest,pop1)]#migration from 5 to 90
       migOD_AG = pop.origin #added
       migOD_AG[,dom.ssp:=1]#added
       migOD_AG[,mrate.pred:=0] #added
       migOD_AG[,ssp.adj:=1] #added
       dom.iper <- copy(migOD_AG)[,Time:=iper][dom.ssp==1, on=.(Time,region),mrate.pred := mrate.pred * ssp.adj] #international migration not used
       
       dom.temp = merge(pop.origin,dom.iper,allow.cartesian=TRUE)
       dom.temp[,odom:=pop1*mrate.pred]
       dom.temp[,sum(odom)] #check = international migration equal to zero
       
       #odom.temp <- copy(odmrdt)[,by=.(Time,region,sex,agest,edu),.(odom=sum(.SD$value))]
       ###idom.temp <- copy(dom.temp)[,by=.(Time,dest,sex,agest,edu),.(idom=sum(.SD$odom))
       ###                           ][,setnames(.SD,"dest","region")] #take destination out. #line below used instead.
       #idom.temp <- copy(idmrdt)[,by=.(Time,region,sex,agest,edu),.(idom=sum(.SD$value))]
       
    # Migration rates applied to the entire period. After outmigration estimations, in-migration is calculated and then adjusted to match out-migration levels.
    # Out-migration considered first to ensure non-negative populations.
       odom.temp <- copy(odmrdt)[,by=.(Time,region,sex,agest,edu),.(odom.rate=sum(.SD$value))]
       odom.temp = merge(pop.origin,odom.temp,allow.cartesian=TRUE)
       odom.temp[,odom:=pop1*odom.rate]
       idom.temp <- copy(idmrdt)[,by=.(Time,region,sex,agest,edu),.(idom.rate=sum(.SD$value))]
       idom.temp = merge(pop.origin,idom.temp,allow.cartesian=TRUE)
       idom.temp[,idom:=pop1*idom.rate]
       idom.temp[,adjust.rate:=(odom.temp[,sum(odom)]/idom.temp[,sum(idom)])] #
       idom.temp[,idom:=pop1*idom.rate*adjust.rate]
       
       
       final.temp[odom.temp,on=id.cols,odom:=i.odom]
       final.temp[idom.temp,on=id.cols,idom:=i.idom]
     }   
     
    
  final.temp[,pop1:=pop1-emi+imm-odom+idom]
   # copy(final.temp)[,.(corr = sum(emi)/sum(imm))]
   if(icheck) { 
     final.summX <-final.temp[agest>-5][,lapply(.SD,sum),.SDcols = vars,by=.(Time)
        ][,stage:="mig"]
      final.summ = rbind(final.summ,final.summX)
      print(final.summ)
      
      print("35")
      final.reg.summX <-final.temp[region=="35"][,lapply(.SD,sum),.SDcols = vars,by=.(Time)][,stage:="mig"]
      final.reg.summ = rbind(final.reg.summ,final.reg.summX)
      print(final.reg.summ)
   }
  
  # stop("..")
  # final.temp[region==22 & agest==5 &sex=="f",]
  # final.temp[region==22 & agest==5&sex=="f",.(sum(pop),sum(pop1),sum(deaths),sum(edutran),sum(idom),sum(odom))]
  # 
   
  #births
  birthsx <- final.temp[sex=="f"][,`:=`(odom=NULL,idom=NULL,emi=NULL,imm=NULL,edutran=NULL,sex=NULL,sx=NULL)][,#this are still empty
      `:=`(popavg=.5*(.SD$pop+shift(.SD$pop1,1,NA,"lag"))),by = .(region,edu)] [,
      `:=`(pop1=NULL,pop=NULL,deaths=NULL)][agest%in%15:49,][asfrdt,#age 15 at the start of iper
       on=setdiff(id.cols,"sex"),#get the asfr 
      `:=`(births=(popavg*ts)*(i.asfr/1000))][#calculate births
        ,popavg:=NULL][srbdt, #bring srb
       on=.(region,Time),`:=`(m=births*i.srb/(1+i.srb),f=births*1/(1+i.srb))][,births:=NULL]
  birthsx <- melt(birthsx,id=setdiff(id.cols,"sex"),variable.name = "sex",value.name = "births")
  
  #update births to mother's row (later to update the final initime)
  final.temp[birthsx,on=id.cols,`:=`(births=i.births)]
  # final.summ <-final.temp[region=="reg356",lapply(.SD,sum),.SDcols = vars,by=.(Time)][,pop1:=pop+births-pop1]
  
  if(icheck) {
    final.summX <-final.temp[agest>-5][,lapply(.SD,sum),.SDcols = vars,by=.(Time)
    ][,pop1:=pop+births-deaths][,stage:="births"]
    final.summ = rbind(final.summ,final.summX)
    print(final.summ)
    
    print("35")
    
    final.reg.summX <-final.temp[region=="35"][,lapply(.SD,sum),.SDcols = vars,by=.(Time)
                                               ][,pop1:=pop+births-deaths][,stage:="births"]
    final.reg.summ = rbind(final.reg.summ,final.reg.summX)
    print(final.reg.summ)
    
  } 
    
  #total births (by edu and sex) will be added to the -5 at final.temp initime
  birthstot = birthsx[,.(pop=sum(births)),by=setdiff(id.cols,"agest")][,agest:=-5]
  
  #update births [ need this for emort e015]
  final.temp[copy(birthstot),on=id.cols,`:=`(pop=i.pop)]
  
  # final.temp[agest==-5,sum(pop)]
  # final.temp[,sum(births)]
  #emort
  # <15 + new born.. get nsx corresponding to the difference in e0_e15
  birthstot <- birthstot[sxdt,on=id.cols,`:=`(pop1=pop*sx,deaths=pop*(1-sx))]
  #add pop pop1 deaths 
  final.temp[copy(birthstot),on=id.cols,`:=`(pop1=i.pop1,deaths=i.deaths)]
  #check this..

  if(icheck) {
    final.summX <-final.temp[,lapply(.SD,sum),.SDcols = vars,by=.(Time)
    ][,pop1:=pop-deaths][,pop:=pop-births][,stage:="sxbirths"]
    final.summ = rbind(final.summ,final.summX)
    print(final.summ)
    
    print("35")
    final.reg.summX <-final.temp[region=="35"
          ][,lapply(.SD,sum),.SDcols = vars,by=.(Time)
            ][,pop1:=pop-deaths][,pop:=pop-births][,stage:="sxbirths"]
    final.reg.summ = rbind(final.reg.summ,final.reg.summX)
    print(final.reg.summ)
  }
  # if(iper == 2020) stop("..")
  #add in final total births initime age -5
  final1[copy(birthstot),on=id.cols,`:=`(pop=i.pop)] #pop1 will be updated later

  #Update the final with pop1, births, mig, edu transition
  final1[copy(final.temp),on=id.cols,
        `:=`(deaths=i.deaths,births=i.births,imm=i.imm,emi=i.emi,odom=i.odom,idom=i.idom,edutran=i.edutran)] #new - without popclass
  
  
  #End of the period age and Time
  #prepare for the next year [5+]
  final.temp.end<-copy(final.temp)[,`:=`(Time=Time+ts,agest=agest+ts,pop=pop1,pop1=NULL)]
  final.temp.end[agest>=95,agest:=95][,pop:=sum(pop),by=id.cols]
  
  # final.temp[,sum(pop)]
  # final.temp.end[,sum(pop)]
   
  #add end of the year population to the final
  final1[final.temp.end,on=id.cols,`:=`(pop = i.pop)]
  
  # stop("..")
  # final.temp.end[region==11 & agest==10 &sex=="f",]
  # final.temp[region==11 & agest==5&sex=="f",.(sum(pop),sum(pop1),sum(deaths),sum(edutran),sum(idom),sum(odom))]
  
  final.temp.end[region==22 & agest==10 &Time==2015 &sex=="f",]
  
  }#loop of iper
}#for single country 

# save final 
{

## basic checks
    final1[agest!=-5,by=.(Time),sum(pop)]
    final1[pop<0,by=.(Time),sum(pop)]
#   #births
    final1[,by=.(Time),sum(births)]
    TFRcheck<-final1[agest%in% 15:45,by=.(Time,agest),.(births=sum(births))]
    TFRcheckw <- final1[agest%in% 15:45 & sex =="f",by=.(Time,agest),.(popf=sum(pop))]
    TFRcheck %<>% 
      mutate(popf = TFRcheckw$popf, asfr=births/5/popf) %>%
      group_by(Time) %>% reframe(TFR=sum(asfr)*5)
    setDT(TFRcheck)
    TFRcheck[,by=.(Time),TFR]
    
#   #deaths
    final1[,by=.(Time),sum(deaths)]#abs deaths
    final1[,by=.(Time),1000*sum(deaths)/5/sum(pop)]#CMR
#   migration
    final1[,by=.(Time),sum(idom)]-final1[,by=.(Time),sum(odom)]

# }
}#End Projection
# # See "Report WIC3.Rmd"
