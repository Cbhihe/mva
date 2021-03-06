# #####################################
##  Topic:    PCA
##  Authors:  Cedric Bhihe, Santi Calvo
##  Date:     2018.03.19
##  Script:   script_pca-svd.R
# #####################################

rm(list=ls(all=TRUE))
library(MASS)    #  exec `install.packages("MASS")` to use 'fractions'
require(graphics)
require(ggplot2)  # exec `install.packages("ggplot2")` in R shell first
library(ggrepel)

options(scipen=6) # R switches to sci notation above 5 digits on plot axes
ccolors=c("red","green","blue","orange","cyan","tan1","darkred","honeydew2","violetred",
          "palegreen3","peachpuff4","lavenderblush3","lightgray","lightsalmon","wheat2")

set.seed(932178)

setwd("~/Documents/Study/UPC/MIRI-subjects/MVA_multivariate-analysis/Labs/")

#############################################
# Load imputed Russet data from Lab 1
#############################################
list_files = as.vector(grep("^russet.*\\mpp.csv$",
                            list.files(path="Data",full.names=FALSE),
                            ignore.case = TRUE,
                            perl = TRUE,
                            fixed = FALSE,
                            inv=FALSE,
                            value=TRUE)
)

russet_imp_data = read.csv(paste0("Data/",list_files[1]),
                       header = TRUE, 
                       quote = "\"", 
                       dec = ".",
                       sep=",", 
                       check.names=TRUE)
dim(russet_imp_data)  # list nbr of observations followed by nbr of vars

# initialize matrices
X <- russet_imp_data ; rm(russet_imp_data)


#############################################
# function for PCA analysis
#############################################

pcaF <- function(X,datestamp,wflag,wparam,...) {
  #attach(X)
  Xdemo <- X$demo   # save categorical variable in object 'Xdemo' 
  cat("X$demo:",Xdemo)
  X <- X[,-9]       # get rid of categorical variable in main data set

  # initialize matrices:
  X_ctd <- matrix(0,nrow(X),ncol(X))
  X_std <- X_ctd
  
  # "wflag" is in c("random","uniform","arbitrary")
  # if arg "wflag" is:
  #   <> "random"
  #      default weight distribution is random uniform 
  #      over interval [0,1], normalized to 1
  #      arg "wparam" is ignored 
  #   <> "uniform"
  #      arg "wparam" is ignored 
  #   <> "arbitrary"
  #      weight distribution is given by vector "wparam"
  #      e.g. wparam <- c(1,2,3,476,34, ...,5,6,123), with length(wparam) <- 47
  #      and individuals' ponderation normalized to 1.
  
  if (wflag == "random") {
    print("ok 'random'")
    # generate random weight for each individual
    W <- runif(nrow(X))
    
  } else if (wflag == "uniform") {
    print("ok 'uniform'")
    # generate uniform weights distribution for each individual
    W=rep(1,nrow(X))
    
  } else if (wflag == "arbitrary") {
    try(if(length(wparam) != nrow(X) | !is.numeric(wparam)) 
      stop("WARNING: invalid individual weights given to function 'pcaF'. 
        Program abort."))
    print("ok 'arbitrary'")
    W <- wparam
    
  } else {
    stop("WARNING: invalid parameter 'wflag' given to function 'pcaF'.
         Program abort.")
  }
  
  N <- diag(W/sum(W),nrow(X),nrow(X))  # build diagonal matrix with normalized weights
  rm(W)
  try(if(abs(sum(diag(N))-1) >= 1e-4) 
    stop("WARNING: invalid normalization of individual weights"))  # check that matrix trace = 1
  
  # centroid G of individuals.
  X_wgt <-  N %*% as.matrix(X)  # weighed observations
  centroid <- apply(X_wgt, 2, sum)  # use 'sum' because N is made of normalized ponderation factors
  rm(X_wgt)
  
  # centered X matrix
  X_ctd <- as.matrix(X - matrix(rep(t(centroid), nrow(X)), ncol=ncol(X), byrow=T))
  colnames(X_ctd) <- colnames(X)
  # covariance matrix (on) X_ctd) 
  covX <- t(X_ctd) %*% N  %*% X_ctd   
  # compare with cov(X) or cov(X_ctd)  # ##########################################################
  print("ok 'covX'")
  
  # standardized X matrix
  colsd <- c()
  # for (cc in 1:ncol(X)) { colsd <- c(colsd,1/sd(X[,cc])) } # build vector of variables' sd(X[,.])
  # X_std <- X_ctd %*% diag(colsd,ncol(X),ncol(X)) # build standardized observation matrix
  # In the above 2 lines, the computation of a standardized matrix only applies to uniformely
  # weighted obs matrices. 
  # If the matrix X is non uniformely weighted, then a ponderation correction must be introduced
  # in the form of:
  X_std <- sweep(X_ctd,2,sqrt(diag(covX)),"/")  # Bug patch contributed by Belchin Adriyanov Kostov
  colnames(X_std) <- colnames(X)
  # correlation matrix (on X_std)
  corX <- t(X_std) %*% N  %*% X_std
  
  evals <- eigen(corX)$values
  cat("Eigenvalues (obs): ",round(evals,4),"\n")
  evecs <- eigen(corX)$vectors
  cat("Eigenvectors (obs):","\n"); evecs
  # sum(diag(corX)) # ##################################################
  cat("Rank of observations' matrix, psi: ",min(ncol(X),ceiling(sum(diag(corX)))),"\n\n")
  
  # screen eigenvalues -> ascertain nbr of significant dimensions
  #   -> cumulative variance explanatory power of principal directions 
  #     (evecs) associated with eigenvalues
  cum_exp_pow=matrix(0,length(evals)+1,1)
  cat("Rank ","eval_power ", "eval_cumul_power\n") 
  for (ii in (1:length(evals))) {
    cum_exp_pow[ii+1] <- cum_exp_pow[ii] + 100*evals[ii]/sum(evals)
    cat(ii," ",round(100*evals[ii]/sum(evals),2)," ",round(cum_exp_pow[ii+1],2),"\n")
    #cum_varexp <- c(cum_varexp,100*(cum_varexp+evals[ii]/sum(evals))) 
  }
  
  # save plot in pdf file
  plotfile = sprintf("Lab2/Report/%s_screen-evals_%s.pdf",
                     datestamp,
                     substr(wflag,1,4))
  pdf(file = plotfile)    # open pdf file
  plottitle = sprintf("PC explanatory power for %s observation weights",wflag)
  plot(seq(1:length(evals)),evals,
       pch=15, 
       cex=1,
       col="blue",
       type="b",
       main=plottitle,
       sub="(Red labels show cumulative variance explanatory power)",
       xlab="Index (sorted)",
       ylab="Eigenvalues"
  )
  text(x=1:length(evals), y=evals, 
       labels=as.character(round(cum_exp_pow[-1,1],2)),
       cex=0.75,
       pos=1,
       col="red")  # add labels
  abline(h=mean(evals),col="gray")
  text(x=6, y=mean(evals)-0.004, 
       labels=paste0("Mean eigenvalue: ",as.character(round(mean(evals),3))),
       cex=0.75,
       pos=3,
       col="red")
  #screeplot(prcomp(covX),npcs=min(ncol(X),length(evals)), type="l", log="y")
  grid()
  dev.off()    # close off pdf file socket
  
  
  
  # psi:  projections of standardized individuals in the EV's direction, (n=47 by p=9 matrix)
  psi <- X_std %*% evecs
  colnames(psi) <- paste0("PC",1:ncol(psi))
  #cat("Individuals' projections on principal directions: ok","\n")
  
  # save 'psi' to disk for later comparison between varying obs ponderations
  write.csv(psi, file=sprintf("Lab2/Report/%s_psi_%s.csv",datestamp, substr(wflag,1,4)))
  
  # check roundoff is contained (compare with eigenvalues, evals).
  #    remember: sum of eigenvalues = rank, p, of multivariate distribution
  #              = trace of cor matrix computed on standardized data in R^p
  try(if(sum(abs(diag(t(psi)%*%N%*%psi) - evals)) >= 1e-4) 
    stop("WARNING: invalid roundoff error in eigenvector and/or eigenvalue computations."))   
  
  
  # projections of centered individuals in the PC1-2 factorial plane
  demo_col=as.factor(Xdemo)
  levels(demo_col) <- c("Stable", "Unstable", "Dictatorship")
  
  # plotfile = sprintf("Lab2/Report/%s_indiv-proj12_%s.pdf",
  #                    datestamp,
  #                    substr(wflag,1,4))
  # pdf(file = plotfile)    # open pdf file
  # plot(psi[,1],psi[,2],
  #      pch=18,
  #      cex=1,
  #      col=demo_col,
  #      type="p",
  #      main=plottitle,
  #      sub=plotsubtitle,
  #      xlab="PC_1",
  #      ylab="PC_2")
  # text(x=psi[,1], y=psi[,2],
  #      labels=rownames(X),
  #      cex=0.75,
  #      pos=3,
  #      col="black")  # add labels
  # abline(h=0,v=0, col="gray")
  # grid()
  # dev.off()    # close pdf file
  
  # In 1st PC plane, PC1 x PC2, compute represented fraction of individuals. 
  represented12 <- c()
  label12 <- c()
  for (ii in 1:nrow(psi)) {
    represented12 <- c(represented12,
                       round(100*norm(as.matrix(psi[ii,1:2]), type="F")/norm(as.matrix(psi[ii,]),type="F"),2))
    label12 <- c(label12,
                 paste0(rownames(psi)[ii],
                        " (",
                        round(100*norm(as.matrix(psi[ii,1:2]), type="F")/norm(as.matrix(psi[ii,]),type="F"),0),
                        "%)")
    )
  }
  cat("Represented inertia of individuals in PC1-PC2 plane:\n");(label12) 
  
  # plot obs projection in PC1-2 factorial plane
  cat("plot obs projections in PC1-2 factorial plane\n")
  plottitle=sprintf("Individuals\' projection in PC1-2 factorial plane (%s weights)",wflag)
  plotdata <- data.frame(PC1=psi[,1],PC2=psi[,2],z=label12)
  plotfile <- sprintf("Lab2/Report/%s_indiv-proj12_%s.pdf",
                      datestamp,
                      substr(wflag,1,4))
  #pdf(file = plotfile)
  ggplot(data = plotdata) + 
    theme_bw() +
    geom_vline(xintercept = 0, col="gray") +
    geom_hline(yintercept = 0, col="gray") +
    geom_text_repel(aes(PC1,PC2,label = z),
                    size=3,
                    point.padding = 0.5,
                    box.padding = unit(0.55, "lines"),
                    segment.size = 0.3,
                    segment.color = 'grey') +
    geom_point(aes(PC1,PC2,col = factor(demo_col)), size = 2) +
    scale_color_discrete(name = 'Political\nregime') +
    labs(title = plottitle)
  #dev.off()
  ggsave(plotfile)

  
  # In 2nd PC plane, PC2 x PC3, compute represented fraction of individuals. 
  represented23 <- c()
  label23 <- c()
  for (ii in 1:nrow(psi)) {
    represented23 <- c(represented23,
                       round(100*norm(as.matrix(psi[ii,c(2,3)]), type="F")/norm(as.matrix(psi[ii,]),type="F"),2))
    label23 <- c(label23,
                 paste0(rownames(psi)[ii],
                        " (",
                        round(100*norm(as.matrix(psi[ii,2:3]), type="F")/norm(as.matrix(psi[ii,]),type="F"),0),
                        "%)")
    )
  }
  cat("Represented inertia of individuals in PC2-PC3 plane:\n",label23) 
  
  # plot in 2nd PC plane, PC2 x PC3
  cat("plot obs projections in PC2-3 factorial plane\n")
  plottitle=sprintf("Individuals\' projection in PC2-3 factorial plane (%s weights)",wflag)
  plotdata <- data.frame(PC2=psi[,2],PC3=psi[,3],z=label23)
  plotfile <- sprintf("Lab2/Report/%s_indiv-proj23_%s.pdf",
                      datestamp,
                      substr(wflag,1,4))
  #pdf(file = plotfile)
  ggplot(data = plotdata) + 
    theme_bw() +
    geom_vline(xintercept = 0, col="gray") +
    geom_hline(yintercept = 0, col="gray") +
    geom_text_repel(aes(PC2,PC3,label = z),
                    size=3,
                    point.padding = 0.5,
                    box.padding = unit(0.55, "lines"),
                    segment.size = 0.3,
                    segment.color = 'grey') +
    geom_point(aes(PC2,PC3,col = factor(demo_col)), size = 2) +
    scale_color_discrete(name = 'Political\nregime') +
    labs(title = plottitle)
  ggsave(plotfile)
  #dev.off()

  
  # In 3rd PC plane, PC1 x PC3, compute represented fraction of individuals. 
  represented13 <- c()
  label13 <- c()
  for (ii in 1:nrow(psi)) {
    represented13 <- c(represented13,
                       round(100*norm(as.matrix(psi[ii,c(1,3)]), type="F")/norm(as.matrix(psi[ii,]),type="F"),2))
    label13 <- c(label13,
                 paste0(rownames(psi)[ii],
                        " (",
                        round(100*norm(as.matrix(psi[ii,c(1,3)]), type="F")/norm(as.matrix(psi[ii,]),type="F"),0),
                        "%)")
    )
  }
  cat("Represented inertia of individuals in PC1-PC3 plane:\n",label13) 
  
  # plot in 3rd PC plane, PC1 x PC3
  cat("plot obs projections in PC1-3 factorial plane\n")
  plottitle=sprintf("Individuals\' projection in PC1-3 factorial plane (%s weights)",wflag)
  plotdata <- data.frame(PC1=psi[,1],PC3=psi[,3],z=label13)
  plotfile <- sprintf("Lab2/Report/%s_indiv-proj13_%s.pdf",
                      datestamp,
                      substr(wflag,1,4))
  #pdf(file = plotfile)
  ggplot(data = plotdata) + 
    theme_bw() +
    geom_vline(xintercept = 0, col="gray") +
    geom_hline(yintercept = 0, col="gray") +
    geom_text_repel(aes(PC1,PC3,label = z),
                    size=3,
                    point.padding = 0.5,
                    box.padding = unit(0.55, "lines"),
                    segment.size = 0.3,
                    segment.color = 'grey') +
    geom_point(aes(PC1,PC3,col = factor(demo_col)), size = 2) +
    scale_color_discrete(name = 'Political\nregime') +
    labs(title = plottitle)
  ggsave(plotfile)
  #dev.off()

  
  # Write representativeness of individual projection in three factorial planes to disk
  representPC123 <- data.frame(cbind(Countries=rownames(X),
                                     Obs_weights=round(diag(N),3),
                                     PC12=represented12,
                                     PC23=represented23,
                                     PC13=represented13))
  colnames(representPC123) <- c("Countries", 
                                "Observation weights", 
                                "PC1-PC2 inertia (%)", 
                                "PC2-PC3 inertia (%)",
                                "PC1-PC3 inertia (%)")
  filename <- sprintf("Lab2/Report/%s_indiv-proj-inert_%s.csv",
                      datestamp,
                      substr(wflag,1,4))
  write.table(representPC123,file=filename,append=F,quote=F,
              sep=",",eol="\n",row.names=F,col.names=T)
  
  
  
  # ############################################################
  # projections of variables in the EV's direction, phi (n=47 by p=8 matrix)
  # ############################################################
  
  cat("Variables' projections on principal directions","\n")
  fooX <- sqrt(N) %*% as.matrix(X_std) %*% as.matrix(t(X_std)) %*% sqrt(N) # n x n matrix, with n=47 
  fooX2 <- sqrt(N) %*% as.matrix(X_std2) %*% as.matrix(t(X_std2)) %*% sqrt(N) # n x n matrix, with n=47 
  
  # compute eigenvalues in R^n
  evals_var <- eigen(fooX)$values
  evals_var2 <- eigen(fooX2)$values
  
  # display relative explanatory power of eigenvalues in R^n
  cum_exp_pow_evals_var=matrix(0,length(evals_var)+1,1)
  cat("Rank ","eval_var_power (%) ", "eval_var_cumul_power (%)\n") 
  for (ii in (1:length(evals_var))) {
    cum_exp_pow_evals_var[ii+1] <- cum_exp_pow_evals_var[ii] + 100*evals_var[ii]/sum(evals_var)
    #cum_varexp <- c(cum_varexp,100*(cum_varexp+evals[ii]/sum(evals))) 
    if (round(cum_exp_pow_evals_var[ii+1],1) < 100 ) {
      cat(ii," ",round(100*evals_var[ii]/sum(evals_var),2)," ",round(cum_exp_pow_evals_var[ii+1],2),"\n")
      jj=ii+1 # last index to display
      }
  }
  cat(jj," ",round(100*evals_var[jj]/sum(evals_var),2)," ",round(cum_exp_pow_evals_var[jj+1],2),"\n")
  cat("Rank of variables' matrix, phi: ",round(sum(evals_var),0),"\n\n")
  #cat("Rank of observation matrix: ",min(nrow(X),ceiling(sum(diag(fooX)))),"\n\n")
  
  # compute eigenvalues in R^n
  evecs_var <- eigen(fooX)$vectors
  evecs_var2 <- eigen(fooX2)$vectors
  # check that vectors are normed, using norm(as.matrix(evecs_var[,x]),type="F") for 1<=x<=8
  #norm(as.matrix(evecs_var[,5]),type="F")  #  ok !
  
  phi_direct <- as.matrix(t(X_std)) %*% sqrt(N) %*% evecs_var  #  result matrix is p x n
  #  phi is p x n, however we're interested in at most the rank(phi)=p=8 first columns
  # Check that all rows are normed according to Frobenius
  #for (ii in 1:nrow(phi_direct)) {cat(ii," ",sqrt(sum(phi_direct[ii,]^2)),"\n")}  # ok !
  colnames(phi_direct) <- paste0("PC",1:ncol(phi_direct))
  # row names are variables names
  
  # Check that cor(X_std,psi) = phi   # ok !
  
  # write 'phi_direct' to disk for obs ponderation comparison
  write.csv(phi_direct, file=sprintf("Lab2/Report/%s_phi_direct_%s.csv",datestamp, substr(wflag,1,4)))
  
  phi_indirect <- sqrt(diag(evals)) %*%  evecs   #  result matrix is p x p
  colnames(phi_indirect) <- paste0("PC",1:ncol(phi_indirect))
  # row names are variables names
  rownames(phi_indirect) <- colnames(X)
  # Check that all rows are normed according to Frobenius
  # for (ii in 1:nrow(phi_indirect)) {cat(ii," ",sqrt(sum(phi_indirect[ii,]^2)),"\n")} 
  #   -> mediocre !
  # check that phi_direct[,1:8] - phi_indirect is reasonably close to [0] 8 x 8 matrix  
  #   -> acceptable !   but we choose to use phi_direct.
  
  
  # compute unit radius circle's cartesian coordinates
  #theta <- as.vector(sweep(as.matrix(rep(1:200),200,byrow=T),2,pi/100,"*"))
  theta <- seq(-pi, pi, length = 200)
  circ_data <- data.frame(xc=cos(theta),yc=sin(theta))
  
  
  # plot in 1st PC plane, PC1 x PC2
  cat("plot variables' projection in PC1-2 factorial plane\n")
  plotfile <- sprintf("Lab2/Report/%s_var-proj12_%s.pdf",
                      datestamp,
                      substr(wflag,1,4))
  plottitle = sprintf("Variables\' projection in PC1-2 factorial\nplane (%s observations' weights)", wflag)
  
  # In 1st PC plane, PC1 x PC2, compute represented fraction of variables. 
  label_phi_direct12 <- c()
  for (ii in 1:nrow(phi_direct)) {
    label_phi_direct12 <- c(label_phi_direct12,
                            paste0(rownames(phi_direct)[ii],
                                   " (",
                                   round(100*norm(as.matrix(phi_direct[ii,1:2]),type="F")/
                                           norm(as.matrix(phi_direct[ii,]),type="F"),0),
                                   "%)")
                            )}
  # pdf(file = plotfile)
  # plot(phi_direct[,1],phi_direct[,2],
  #      pch=15, 
  #      cex=1,
  #      col="blue",
  #      type="p",
  #      main=plottitle,
  #      # sub=sprintf("(%s obs. weights)", wflag),
  #      xlab="PC1",
  #      ylab="PC2")
  # text(x=phi_direct[,1], y=phi_direct[,2], 
  #      labels=label_phi_direct12,
  #      cex=0.75,
  #      pos=1,
  #      col="red")  # add labels
  # grid()
  # dev.off()

  plotdata <- data.frame(PC1=phi_direct[,1],PC2=phi_direct[,2],z=label_phi_direct12)
  varproj_plot <- ggplot(data = plotdata) + 
    theme_bw()+
    geom_vline(xintercept = 0, col="gray") +
    geom_hline(yintercept = 0, col="gray") +
    #geom_text_repel(aes(PC1,PC2,label = z))+
    geom_text_repel(aes(PC1,PC2,label = z),
                    size=3,
                    point.padding = 0.5,
                    box.padding = unit(0.55, "lines"),
                    segment.size = 0.3,
                    segment.color = 'grey') +
    geom_point(aes(PC1,PC2),col = "blue", size = 1) +
    #geom_path(circ_data,aes(xc,yc), inherit.aes =F) +
    #geom_point(aes(x_coord,y_coord),col = "black", size = 0.2) +
    geom_segment(data = plotdata, 
                 mapping = aes(x = 0, y = 0, xend = PC1, yend = PC2),
                 color="blue",
                 arrow=arrow(length=unit(2,"mm")))+
    labs(title = plottitle)+
    coord_fixed()
  varproj_plot + geom_path(aes(xc, yc), data = circ_data, col="grey70")
  
  ggsave(plotfile)

  
  # plot in 2nd PC plane, PC2 x PC3
  cat("Plot variables' projection in PC2-3 factorial plane\n")
  plotfile <- sprintf("Lab2/Report/%s_var-proj23_%s.pdf",
                      datestamp,
                      substr(wflag,1,4))
  plottitle = sprintf("Variables\' projection in PC2-3 factorial\nplane (%s observations' weights)", wflag)
  
  # In 2nd PC plane, PC2 x PC3, compute represented fraction of variables. 
  label_phi_direct23 <- c()
  for (ii in 1:nrow(phi_direct)) {
    label_phi_direct23 <- c(label_phi_direct23,
                            paste0(rownames(phi_direct)[ii],
                                   " (",
                                   round(100*norm(as.matrix(phi_direct[ii,2:3]),type="F")/
                                           norm(as.matrix(phi_direct[ii,]),type="F"),0),
                                   "%)")
    )
  }
  
  plotdata <- data.frame(PC2=phi_direct[,2],PC3=phi_direct[,3],z=label_phi_direct23)
  varproj_plot <- ggplot(data = plotdata) + 
    theme_bw()+
    geom_vline(xintercept = 0, col="gray") +
    geom_hline(yintercept = 0, col="gray") +
    geom_text_repel(aes(PC2,PC3,label = z),
                    size=3,
                    point.padding = 0.5,
                    box.padding = unit(0.55, "lines"),
                    segment.size = 0.3,
                    segment.color = 'grey') +
    geom_point(aes(PC2,PC3),col = "blue", size = 1) +
    #geom_path(circ_data,aes(xc,yc), inherit.aes =F) +
    #geom_point(aes(x_coord,y_coord),col = "black", size = 0.2) +
    geom_segment(data = plotdata, 
                 mapping = aes(x = 0, y = 0, xend = PC2, yend = PC3),
                 color="blue",
                 arrow=arrow(length=unit(2,"mm")))+
    labs(title = plottitle)+
    coord_fixed()
  
  varproj_plot + geom_path(aes(xc, yc), data = circ_data, col="grey70")
  
  ggsave(plotfile)
  
  
  
  # plot in 3rd PC plane, PC1 x PC3
  cat("Plot variables' projection in PC1-3 factorial plane\n")
  plotfile <- sprintf("Lab2/Report/%s_var-proj13_%s.pdf",
                      datestamp,
                      substr(wflag,1,4))
  plottitle = sprintf("Variables\' projection in PC1-3 factorial\nplane (%s observations' weights)", wflag)
  
  # In 3rd PC plane, PC1 x PC3, compute represented fraction of variables. 
  label_phi_direct13 <- c()
  for (ii in 1:nrow(phi_direct)) {
    label_phi_direct13 <- c(label_phi_direct13,
                            paste0(rownames(phi_direct)[ii],
                                   " (",
                                   round(100*norm(as.matrix(phi_direct[ii,c(1,3)]),type="F")/
                                           norm(as.matrix(phi_direct[ii,]),type="F"),0),
                                   "%)")
    )
  }
  
  plotdata <- data.frame(PC1=phi_direct[,1],PC3=phi_direct[,3],z=label_phi_direct13)
  varproj_plot <- ggplot(data = plotdata) + 
    theme_bw()+
    geom_vline(xintercept = 0, col="gray") +
    geom_hline(yintercept = 0, col="gray") +
    geom_text_repel(aes(PC1,PC3,label = z),
                    size=3,
                    point.padding = 0.5,
                    box.padding = unit(0.55, "lines"),
                    segment.size = 0.3,
                    segment.color = 'grey') +
    geom_point(aes(PC1,PC3),col = "blue", size = 1) +
    #geom_path(circ_data,aes(xc,yc), inherit.aes =F) +
    #geom_point(aes(x_coord,y_coord),col = "black", size = 0.2) +
    geom_segment(data = plotdata, 
                 mapping = aes(x = 0, y = 0, xend = PC1, yend = PC3),
                 color="blue",
                 arrow=arrow(length=unit(2,"mm")))+
    labs(title = plottitle)+
    coord_fixed()
  
  varproj_plot + geom_path(aes(xc, yc), data = circ_data, col="grey70")
  
  ggsave(plotfile)
  
  
  # #####################################################
  # Compute the correlation of the variables with the significant PCs 
  # #####################################################

  # significant PCs in R^n are given by:
  # First, establish which are the significant component. Use Kaiser rule:
  mean_evals_var=mean(evals_var[1:ceiling(round(sum(evals_var),2))])
  significant=0
  for (kk in 1:round(sum(evals_var),0)) {
    if (evals_var[kk] >= mean_evals_var){
      significant =significant+1
      cat("eigenvalue ",kk,": ",round(evals_var[kk],2),"\n")
    }
  }
  cat("There are ",significant," significant PCs.\n\n")
  
  phi_direct[,1:significant]  # 
  
  
} #  function closure
  

datestamp <- format(Sys.time(),"%Y%m%d-%H%M%S"); 
pcaF(X,datestamp,wflag="uniform")
#pcaF(X,datestamp,wflag="random")

# toy arbitrary example:
#weights <- rep(1:10,5); length(weights) <- nrow(X) 
# Cuba-centered PCA, with Cuba's weight set to 0
obs_weights <- read.csv(file=sprintf("Data/%s_arbitrary-wparam.csv","20180319-131250"))
wparam <- obs_weights[,2]
pcaF(X,datestamp,wflag="arbitrary",wparam=obs_weights[,2])


# After having performed Cuba-centered PCA (Cuba being considered an outlier),
# compute correlations of the obtained significant components psi_arbi 
# with psi_unif
datestamp <- "201803-085020"
psi_arbi <- read.csv(file=sprintf("Lab2/Report/%s_psi_arbi.csv",datestamp)) # Cuba-centered
rownames(psi_arbi) <- psi_arbi[,1]; psi_arbi <- psi_arbi[,-1]

datestamp <- "20180320-085019"
psi_unif <- read.csv(file=sprintf("Lab2/Report/%s_psi_unif.csv",datestamp)) # uniform weights
rownames(psi_unif) <- psi_unif[,1]; psi_unif <- psi_unif[,-1]

# 3 significant components for uniform and arbitrary ponderations (Cuba weight set to 0)
diag(cor(psi_arbi[,1:3],psi_unif[,1:3]))

