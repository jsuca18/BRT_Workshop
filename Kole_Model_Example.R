#example running of BRTs using Kole distribution from SPC data for MHI
library(matrixStats)
library(fmsb)

source("BRT_Eval_Function_JJS.R")

df<-readRDS("Kole_Dataset_Workshop.rds")
is.nan.data.frame <- function(x)
  do.call(cbind, lapply(x, is.nan))
df[is.nan(df)] <- NA
df$PA[df$CTST>0]<-1
df$PA[df$CTST==0]<-0

Predictors<-which(!colnames(df) %in% c("CTST","PA") )

Response<-which(colnames(df) %in% c("PA") )
PA_Model_Step<-fit.brt.n_eval_Balanced(df, gbm.x=Predictors, gbm.y= c(Response), lr=0.001, tc=3, family = "bernoulli",bag.fraction=0.75, n.folds=5, 5)

PA_Model<-PA_Model_Step[[1]]
Model_Evals_PA<-unlist(unlist(PA_Model_Step[[2]]))

Model_PA_Eval<-matrix(,length(PA_Model),2)
for (i in 1:length(PA_Model)){
  Model_PA_Eval[i,1]<-Model_Evals_PA[[i]]@auc
  Model_PA_Eval[i,2]<-max(Model_Evals_PA[[i]]@TPR+Model_Evals_PA[[i]]@TNR-1)
}

print(summary(Model_PA_Eval[,1]))
print(summary(Model_PA_Eval[,2]))

#now reduce to 'non-random' predictors
var_tested<-names(df[,Predictors])

iters=length(PA_Model)
percent_contrib<-NULL#list()
for(q in 1:iters){                               
  sum1<-summary(PA_Model[q][[1]]  , plot=F )
  sum2<-sum1[order(sum1[,1], levels = var_tested),]
  percent_contrib<-cbind(percent_contrib, sum2[,2])
  rownames(percent_contrib)<-sum1[order(sum1[,1], levels = var_tested),1]
}


Mean_PA_Contributions<-as.data.frame(t(rowMeans(percent_contrib)))

Predictors_to_Keep_Index<-which(Mean_PA_Contributions>Mean_PA_Contributions$Random)

Predictors_to_Keep<-Mean_PA_Contributions[,Predictors_to_Keep_Index]
Reduced_Predictors<-which(colnames(df) %in% colnames(Predictors_to_Keep))

#refit model
PA_Model_Reduced<-fit.brt.n_eval_Balanced(df, gbm.x=Reduced_Predictors, gbm.y= c(Response), lr=0.001, tc=3, family = "bernoulli",bag.fraction=0.75, n.folds=5, 5)


#re-evaluate model fit


PA_Model<-PA_Model_Reduced[[1]]


Model_Evals_PA<-unlist(unlist(PA_Model_Reduced[[2]]))

Model_PA_Eval<-matrix(,length(PA_Model),2)

for (i in 1:length(PA_Model)){
  Model_PA_Eval[i,1]<-Model_Evals_PA[[i]]@auc
  Model_PA_Eval[i,2]<-max(Model_Evals_PA[[i]]@TPR+Model_Evals_PA[[i]]@TNR-1)
}

print(summary(Model_PA_Eval[,1]))
print(summary(Model_PA_Eval[,2]))



#recalculate variable importance for the reduced model
#
var_tested<-names(df[,Reduced_Predictors])

percent_contrib<-NULL
iters=length(PA_Model)
part_plot<-list()
part_plot<-list()
percent_contrib<-NULL#list()
Cont_Preds<-names(Filter(is.numeric,df[,Reduced_Predictors]))
Num_Preds<-which(var_tested %in% Cont_Preds)

for(q in 1:iters){                                #this was 50 
  mod<-PA_Model[q][[1]] 
  ###
  part_plot1<-data.frame(row.names=1:100)
  for(x in Num_Preds){ ###
      pp<-plot(mod ,var_tested[x],return.grid=T) ###
      part_plot1<-cbind(part_plot1, pp) ###
 }###
  
  ###
  part_plot[[q]]<-part_plot1 ###
  
  sum1<-summary(PA_Model[q][[1]]  , plot=F )
  sum2<-sum1[order(sum1[,1], levels = var_tested),]
  percent_contrib<-cbind(percent_contrib, sum2[,2])
  rownames(percent_contrib)<-sum1[order(sum1[,1], levels = var_tested),1]
}
All_percent_contribution<-cbind(rownames(percent_contrib), paste(round(rowMeans(percent_contrib),2), round(rowSds(percent_contrib),2), sep=" ± "))
Combined_All_percent_contribution<-All_percent_contribution


Mean_PA_Contributions<-as.data.frame(t(rowMeans(percent_contrib)))
PA_Predictors_Plot<- rbind(rep(max(Mean_PA_Contributions),length(var_tested)) , rep(0,length(var_tested)) , Mean_PA_Contributions)
PA_Predictors_Plot[]<-sapply(PA_Predictors_Plot, as.numeric)
par(mfrow=c(1,1))

radarchart(PA_Predictors_Plot,  pfcol=rgb(0.0,0.3,0.5,0.5), pcol=rgb(0.0,0.3,0.5,0.5), title="Kole P/A" )

Variable_List<-as.data.frame(t(Mean_PA_Contributions))
Variable_List$Variables<-rownames(Variable_List)
Variable_List<-Variable_List[order(-Variable_List$V1),]


Num_Preds<-which(rownames(Variable_List) %in% Cont_Preds)

dev.new()
par(mfrow=c(4,3))
mn_part_plot<-list()  
for(y in Num_Preds){
  id<-which(colnames(part_plot[[1]])==Variable_List$Variables[y])
  all1<-NULL
  all2<-NULL
  for(z in 1:iters){											 #this was 50 
    all1<-rbind(all1, cbind(c(part_plot[[z]][,id])))
    all2<-rbind(all2, cbind(c(part_plot[[z]][,id+1])))
  }
  all3<-cbind(all1, all2)
  all1<-all3[order(all3[,1]),]
  
  plot(all1, xlab=Variable_List$Variables[y], col="white", ylab=paste("f(",Variable_List$Variables[y], ")", sep=""),cex.axis=1.2, cex.lab=1.2) #, ylim=c(-8,2))
  plx<-predict(loess(all1[,2] ~ all1[,1], span = 0.3), se=T)
  mn_part_plot[[y]]<- cbind(all1[,1], plx$fit)      
  lines(all1[,1],plx$fit)
  lines(all1[,1],plx$fit - qt(0.975,plx$df)*plx$se, lty=2)#0.975
  lines(all1[,1],plx$fit + qt(0.975,plx$df)*plx$se, lty=2)
  rug(na.omit(unlist(df[Variable_List$Variables[y]])))
  legend("bottomright", paste(All_percent_contribution[which(All_percent_contribution[,1]==Variable_List$Variables[y]),2],"%", sep=" "), bty="n", cex=1.4)
}


######now make abund. only model#################

df_pres<-df[df$PA==1,]
df_pres$Log_Abund<-log(df_pres$CTST)
Response<-which(colnames(df_pres) %in% c("Log_Abund") )

#fit model to all predictors
Abund_Model_Step<-fit.brt.n_eval_Balanced(df_pres, gbm.x=Predictors, gbm.y= c(Response), lr=0.001, tc=3, family = "gaussian",bag.fraction=0.75, n.folds=5, 5)

Abund_Model<-Abund_Model_Step[[1]]

#check model fit for R2 and RMSE 
Model_Evals_Abund<- data.frame(matrix(unlist(Abund_Model_Step[[2]]), nrow=length(Abund_Model_Step[[2]]), byrow=TRUE))
colnames(Model_Evals_Abund)<-c("R2","RMSE")

print(summary(Model_Evals_Abund[,1]))
print(summary(Model_Evals_Abund[,2]))


#now reduce to 'non-random' predictors
var_tested<-names(df_pres[,Predictors])

iters=length(Abund_Model)
percent_contrib<-NULL#list()
for(q in 1:iters){                               
  sum1<-summary(Abund_Model[q][[1]]  , plot=F )
  sum2<-sum1[order(sum1[,1], levels = var_tested),]
  percent_contrib<-cbind(percent_contrib, sum2[,2])
  rownames(percent_contrib)<-sum1[order(sum1[,1], levels = var_tested),1]
}


Mean_PA_Contributions<-as.data.frame(t(rowMeans(percent_contrib)))

Predictors_to_Keep_Index<-which(Mean_PA_Contributions>Mean_PA_Contributions$Random)

Predictors_to_Keep<-Mean_PA_Contributions[,Predictors_to_Keep_Index]
Reduced_Predictors<-which(colnames(df_pres) %in% colnames(Predictors_to_Keep))

#refit model
Abund_Model_Reduced<-fit.brt.n_eval_Balanced(df_pres, gbm.x=Reduced_Predictors, gbm.y= c(Response), lr=0.001, tc=3, family = "gaussian",bag.fraction=0.75, n.folds=5, 5)


#re-evaluate model fit


Abund_Model<-Abund_Model_Reduced[[1]]


Model_Evals_Abund<- data.frame(matrix(unlist(Abund_Model_Reduced[[2]]), nrow=length(Abund_Model_Reduced[[2]]), byrow=TRUE))
colnames(Model_Evals_Abund)<-c("R2","RMSE")

print(summary(Model_Evals_Abund[,1]))
print(summary(Model_Evals_Abund[,2]))


#plot variable importance and partial dependence plots.

var_tested<-names(df_pres[,Reduced_Predictors])

percent_contrib<-NULL
iters=length(Abund_Model)
part_plot<-list()
part_plot<-list()
percent_contrib<-NULL
Cont_Preds<-names(Filter(is.numeric,df_pres[,Reduced_Predictors]))
Num_Preds<-which(var_tested %in% Cont_Preds)

for(q in 1:iters){                               
  mod<-Abund_Model[q][[1]] 
  ###
  part_plot1<-data.frame(row.names=1:100)
  for(x in Num_Preds){ ###
    pp<-plot(mod ,var_tested[x],return.grid=T) ###
    part_plot1<-cbind(part_plot1, pp) ###
  }###
  
  ###
  part_plot[[q]]<-part_plot1 ###
  
  sum1<-summary(Abund_Model[q][[1]]  , plot=F )
  sum2<-sum1[order(sum1[,1], levels = var_tested),]
  percent_contrib<-cbind(percent_contrib, sum2[,2])
  rownames(percent_contrib)<-sum1[order(sum1[,1], levels = var_tested),1]
}
All_percent_contribution<-cbind(rownames(percent_contrib), paste(round(rowMeans(percent_contrib),2), round(rowSds(percent_contrib),2), sep=" ± "))
Combined_All_percent_contribution<-All_percent_contribution


Mean_Abund_Contributions<-as.data.frame(t(rowMeans(percent_contrib)))
Abund_Predictors_Plot<- rbind(rep(max(Mean_Abund_Contributions),length(var_tested)) , rep(0,length(var_tested)) , Mean_Abund_Contributions)
Abund_Predictors_Plot[]<-sapply(Abund_Predictors_Plot, as.numeric)
par(mfrow=c(1,1))

radarchart(Abund_Predictors_Plot,  pfcol=rgb(0.0,0.3,0.5,0.5), pcol=rgb(0.0,0.3,0.5,0.5), title="Kole Abund." )

Variable_List<-as.data.frame(t(Mean_Abund_Contributions))
Variable_List$Variables<-rownames(Variable_List)
Variable_List<-Variable_List[order(-Variable_List$V1),]


Num_Preds<-which(rownames(Variable_List) %in% Cont_Preds)

dev.new()
par(mfrow=c(5,3))
mn_part_plot<-list()  
for(y in Num_Preds){
  id<-which(colnames(part_plot[[1]])==Variable_List$Variables[y])
  all1<-NULL
  all2<-NULL
  for(z in 1:iters){											 
    all1<-rbind(all1, cbind(c(part_plot[[z]][,id])))
    all2<-rbind(all2, cbind(c(part_plot[[z]][,id+1])))
  }
  all3<-cbind(all1, all2)
  all1<-all3[order(all3[,1]),]
  
  plot(all1, xlab=Variable_List$Variables[y], col="white", ylab=paste("f(",Variable_List$Variables[y], ")", sep=""),cex.axis=1.2, cex.lab=1.2) #, ylim=c(-8,2))
  plx<-predict(loess(all1[,2] ~ all1[,1], span = 0.3), se=T)
  mn_part_plot[[y]]<- cbind(all1[,1], plx$fit)      
  lines(all1[,1],plx$fit)
  lines(all1[,1],plx$fit - qt(0.975,plx$df)*plx$se, lty=2)#0.975
  lines(all1[,1],plx$fit + qt(0.975,plx$df)*plx$se, lty=2)
  rug(na.omit(unlist(df_pres[Variable_List$Variables[y]])))
  legend("bottomright", paste(All_percent_contribution[which(All_percent_contribution[,1]==Variable_List$Variables[y]),2],"%", sep=" "), bty="n", cex=1.4)
}


#########Now compare hurdle model fit############
PA_Predictions<-matrix(, nrow=nrow(df), ncol=length(PA_Model))
Abund_Predictions<-matrix(, nrow=nrow(df), ncol=length(Abund_Model))

for (k in 1:length(PA_Model)){
  PA_Predictions[,k]<-predict.gbm(PA_Model_Reduced[[1]][[k]], df, n.trees=PA_Model_Reduced[[1]][[k]]$n.trees, type="response")
  Abund_Predictions[,k]<-predict.gbm(Abund_Model_Reduced[[1]][[k]], df, n.trees=Abund_Model_Reduced[[1]][[k]]$n.trees, type="response")
  
  }                   
PA_Estimates<-rowMeans(PA_Predictions,na.rm=T)
Abund_Estimates<-rowMeans(Abund_Predictions,na.rm=T)
df<-cbind(df, PA_Estimates, Abund_Estimates)
df$Hurdle_Estimate<-df$PA_Estimates*exp(df$Abund_Estimates)

cor.test(df$CTST,df$Hurdle_Estimate)
cor(df$CTST,df$Hurdle_Estimate)^2
plot(df$Hurdle_Estimate, df$CTST)
plot(df$Hurdle_Estimate, df$CTST)
plot(df$PA_Estimates, df$CTST)
plot(df$Abund_Estimates, df$CTST)

