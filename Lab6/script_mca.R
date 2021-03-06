# ############################################
##  Topic:      Multiple Correspondence Analysis
##  Authors:    Cedric Bhihe
##  Date:       2018.05.22
##  Script:     script_mca.R
# ##############################################

rm(list=ls(all=TRUE))

# ############################################
## Environment and env. var.
# ############################################

options(scipen=6) # R switches to sci notation above 5 digits on plot axes
set.seed(932178)
setwd("~/Documents/Academic/UPC/MIRI/Subjects/MVA_multivariate-analysis/Labs/")

ccolors=c("red","green","blue","orange","cyan","tan1","darkred","honeydew2","violetred",
          "palegreen3","peachpuff4","lavenderblush3","lightgray","lightsalmon","wheat2")
datestamp <- format(Sys.time(),"%Y%m%d-%H%M%S"); 


# ############################################
## Repos and libraries
# ############################################

setRepositories(ind = c(1:6,8))
#setRepositories()   # specify repo interactively
#chooseCRANmirror()  # specify mirror interactively

#install.packages("FactoMineR",dependencies=T)
library(FactoMineR, lib.loc="~/R/x86_64-pc-linux-gnu-library/3.5")   # to use PCA method
#install.packages("factoextra",dependencies=T)
library("factoextra")
#install.packages("mice",dependencies=T)
library("mice")
#install.packages("VIM",dependencies=T)
library("VIM")
require(graphics)       # enhanced graphics
library(ggplot2, lib.loc="~/R/x86_64-pc-linux-gnu-library/3.5")      # to enhance graph plotting
library(ggrepel, lib.loc="~/R/x86_64-pc-linux-gnu-library/3.5")      # to plot with well behaved labeling


# #############################
## Functions
# #############################
csvSaveF <- function(dataObj,targetfile) {
  write.table(dataObj,
              targetfile,
              append=F,
              sep=",",
              eol="\n",
              na ="NA",
              dec=".",
              row.names=F,
              col.names=T)
}    # save cvs to file on disk

# ############################################
## 1: Read the mca_car.csv data set
#############################################

cars = read.csv("Data/mca_car.csv",
                header = TRUE, 
                quote = "\"", 
                dec = ".",
                sep=",", 
                encoding="UTF-8",
                check.names=TRUE,
                 stringsAsFactors = TRUE)
rownames(cars) <- cars[,1]
cars <- cars[,-1]
## Exploring the dataset

# The table contains categorical information and is not a frequency table. Therefore the  Pearson 
# chi-square test, `chisq.test()`, for significant association (dependence) between row & col 
# categs is not adequate.

class(cars)
dim(cars)
summary(cars)


cars_aggr <- aggr(cars, 
                  numbers=TRUE,
                  bars=TRUE,
                  combined=FALSE,
                  prop=FALSE,
                  plot=TRUE,
                  axes=TRUE,
                  col=ccolors[6:7], 
                  labels=names(cars),
                  cex.axis=1,
                  ylab=c("Missing Data (count)","In-Variable Missing Data Distribution"))

summary(cars_aggr)   # There are no missings

#xtabs(formula = ~precio, data=cars)

marktSeg <- with(cars,table(marca,precio_categ))[,order(match(colnames(with(cars,table(marca,precio_categ))),
                                                  c("cheap","medium","expensive","luxury")))]
marktSeg <- xtabs(~cars$marca+cars$precio_cat)[,order(match(colnames(with(cars,table(marca,precio_categ))),
                                                            c("cheap","medium","expensive","luxury")))] # same as above

marktSeg_norm <- sweep(marktSeg,1,margin.table(marktSeg,1),"/")  # row-wise normalized market segmentation for each brand
marktSeg_norm <- prop.table(marktSeg,1)  # same as above
apply(marktSeg_norm,1,function(x) sum(x)) # check that all rows sum up to 1
marktSeg_norm <- marktSeg_norm[order(marktSeg_norm[,4],-marktSeg_norm[,1]),]
marktSeg_norm = t(marktSeg_norm)  # transpose to be able to use stacked barplot

barplot(round(marktSeg_norm*100,0),
        ylab="Normalized segmentation (%)",
        main='Fig.1: Product segmentation per brand',
        las=2,
        cex.names=0.7,
        col=c("blue","cyan","yellow","orange"),
        xlim=c(0, ncol(marktSeg_norm) + 12),  # make space for legend
        legend.text = T,
        args.legend=list(
            x=ncol(marktSeg_norm) + 19,
            y=100,
            bty = "n" # box type around legend
        ))

chisq.test(marktSeg) 
# we reject the H0 hypothesis that the two factors are independent from (or unrelated to) one another.

## Further visualize other statistics with aggregate()
consumo <- unlist(strsplit(as.character(cars$consumo),",", fixed=T))
gasConsum <- c()
# select maximum gas consumption for every car model
for (ii in 1:length(consumo)){
    if (ii%%2==0) { gasConsum <- c(gasConsum,as.numeric(strtrim(consumo[ii],nchar(consumo[ii])-1)))}
} 
cilindrada <- unlist(strsplit(as.character(cars$cilindrada),",", fixed=T))
cylDisp <- c()
for (ii in 1:length(cilindrada)){
    if (ii%%2==0) { cylDisp <- c(cylDisp,as.numeric(strtrim(cilindrada[ii],nchar(cilindrada[ii])-1)))}
}
procdata <- as.data.frame(cbind(make=as.character(cars$marca),
                                prodSeg=as.character(cars$precio_categ),
                                cylDisp=cylDisp,
                                gasConsum=gasConsum))
cars_aggr01 <- aggregate(cbind(cylDisp,gasConsum)~make+prodSeg,procdata,mean)  # data.frame object
cars_aggr01 <- cars_aggr01[cars_aggr01$make %in% c("ALFA ROMEO", "BENTLEY", "VOLVO", "CITROEN"),]
# print with re-ordered "precio_categ" column
cars_aggr01[order(match(cars_aggr01[,2],c("cheap","medium","expensive","luxury"))),]


# ############################################
## 2: Multiple Correspondence Analysis
#############################################
# brand and categorical price vars are made suplementary, other vars remain active.
par(mfrow=c(1,1))

mcaCars <- MCA(cars,ncp=7,
               quanti.sup=c(17),
               quali.sup=c(18,19),
               excl=NULL,
               graph = T,
               level.ventil = 0.00,
               axes = c(1,2),
               row.w = NULL,
               method="Indicator",
               na.method="NA",
               tab.disj=NULL)

## visualize summary of MCA results for arbitrary nbr of observations 
# nbelements=10   default
# nbelements=Inf  for all obs
summary(mcaCars,nbelements=Inf,file="Lab6/Report/mcaCars_summary.txt") # commit to disk
summary(mcaCars,nbelements=12)
# for each obs/individual: 
  # 'Dim.{1,2,3}' are coordinates of obs on PC axes, psi[,1..3]
  # 'ctr' are contributions to PC direction, such that col.sum = 1
  # 'cos2' is quality of representation of individual along given PC direction
# for each active categorical var:
  # 'Dim.{1,2,3}' are coordinates of var on PC axes, psi[,1..3]
  # 'ctr' are contributions of var to PC direction, such that col.sum = 1
  # 'cos2' is quality of representation of var along given PC direction
  # 'v.test' (for either active or illustrative (non-active) categorical vars)
     # if in ]-2,+2[ the var's coordinate is not significantly different from 0 
     # if outside ]-2,+2[, psi's PC axis coord is significantly less than 0 = coord of centroid
     # In other words, individuals expressing that modality are NOT picked at random. 
     # We reject H0: "modality's mean for group/cluster = global modality mean", 
     #+ i.e. "individuals expressing that modality are chosen at random"
  # 'heta²' is the squared correlation ratio used in one way ANOVA. It represents
  #+ correlation between the categorical var and the dimension or PC direction.
# for each supplementary categorical var, results are presented as for active categor vars.
#+ except there is no contribution to the construction of dimensions (PCs) in the analysis
  # 'Dim.{1,2,3}'
  # 'cos2'
  # 'v.test'
  # 'heta²'
# for each supplementary continuous var
  # coordinates for each of the dimensions (PC axes) represent correlations between var and axes

# Note that the contribution of categorical vars cannot be deduced from its position (away from the 
#+ origin) on the graph. It is because its contribution is generally influenced by its frequency of 
#+ occurence. A low frequency entails a large contribution. => read contribs from output !!!

attributes(mcaCars) # structure of data in mcaCars
mcaCars$eig  # get evals 
             # + variance explanation power 
             # + cumulative percentage of explained variance 


par(mfrow=c(1,2))

fviz_mca_ind(mcaCars,
             axes = c(1, 2),
             geom="point",
             col.ind = "cos2",
             label="none", habillage=c(19),
             addEllipses=TRUE, ellipse.level=0.95)
fviz_mca_ind(mcaCars,
             axes = c(1, 2),
             geom="point",
             col.ind = "cos2")
# plot(mcaCars,
#      invisible=c("var","quali.sup","quanti.sup"),
#      cex=0.8,
#      selectMod="contrib 20",
#      unselect="grey30")
# plot(mcaCars,
#      invisible=c("ind","quali.sup","quanti.sup"), # print only vars
#      cex=0.8, 
#      selectMod="cos2 0.2",   # only vars whose cos2 >=.2
#      unselect="grey30")
# plot(mcaCars,
#      invisible=c("quali.sup","quanti.sup"),  # print vars and obs
#      cex=0.8,
#      selectMod="cos2 0.2", # only var (categories) and observation whose cos2 >= 0.2
#      select="contri 10", # 10 obs that contribute most
#      unselect="grey30")
# plot(mcaCars,
#      choix="var",
#      xlim=c(0,0.5),ylim=c(0,0.5), # zoom into graph
#      cex=0.7)

# Coords on a dimension for:
  # categorical vars = squared correlation ratio between Dim and categor var.
  # continuous vars = squared correlation coeff between Dim and continuous var.

plot(mcaCars,
     invisible=c("var","quali.sup","quanti.sup"),
     habillage="frequency")

par(mfrow=c(1,1))

fviz_mca_var(mcaCars,
             axes = c(1, 2),
             choice=c("var"),
             # col.var="cos2",
             gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07"),
             shape.var = 15,
             geom=c("point","text"),
             repel=T)

fviz_mca_biplot(mcaCars,
             axes = c(1, 2),
             palette="ucscgb",
             label=c("quali.sup", "quanti.sup"),
             repel =T,
             addEllipse=T, habillage=c(19),
             addEllipses=TRUE, ellipse.level=0.95)

par(mfrow=c(1,1))


#############################################
## 3: Interpret 1st 2 factors
## 4: Nbr of significant dimensions
#############################################
# See report for interpretation
mcaCars$var$coord
mcaCars$var$cos2
dimdesc(mcaCars)

# Top 10 active variables with the highest cos2
fviz_mca_var(mcaCars, select.var= list(cos2 = 10))

# top 5 contributing individuals and variable categories
fviz_mca_biplot(mcaCars, select.ind = list(contrib = 5), 
                select.var = list(contrib = 5),
                ggtheme = theme_minimal())

fviz_screeplot(mcaCars, addlabels = TRUE, ylim = c(0, 20)) #  Caution ! No correction for mean here
evals <- get_eigenvalue(mcaCars)[,1]  # 2nd and 3rd columns are % inertia explained and cumulative percentage
evals_c <- evals-mean(evals)  # corrected eigenvalues
evals_c <- evals_c[evals_c>0]

plot(evals_c/sum(evals_c),
     col="blue",
     type="b", 
     xlab="Dimensions",ylab="Cumulative inertia explained",
     main="Scree plot for MCA of \'Cars\' dataset")
nd <-6
cat("Inertia explained:",cumsum(100*evals_c/sum(evals_c))[nd],"\n")


# ############################################
## 5: hierarchical clustering with significant factors, 
#     discuss nbr of final classes 
#     consolidation clustering.
# ############################################
psiCars <- mcaCars$ind$coord[,1:nd]   # yields obs coordinates, for nd significant dim, in PC factorial space, R^min(p,nd)
distCars <- dist(psiCars, method = "euclidean")
treeCars <- hclust(distCars, method = "ward.D2")
treeJoins <- length(treeCars$height)

par(mfrow=c(1,2))

# plot join-distances at each iteration
barplot((treeCars$height[(treeJoins-40):(treeJoins)]),main="Aggregated distance at each iteration")
abline(h=10,col="red")
text(x=24, y=10-0.04, 
     labels="Dendrogram tree-cut",
     cex=0.75,
     pos=3,
     col="red")

NC = 5  #  <<<<<<<<  OUR CONCLUSION / CHOICE !!!!!!!!!!
cut <- cutree(treeCars,k=NC)  # identifying levels to indiv. according to NC clusters

# compute size of clusters
cat("Sizes of clusters (before consolidation):", table(cut),"\n")

# plot dendrogram
plot(treeCars,
     main='Hierarchical Clustering (Ward.D2)',
     xlab='Distance',
     cex=0.6,
     label=F)
abline(h=10,col='red')
rect.hclust(treeCars, k=NC, border="green") 

par(mfrow=c(1,1))


## calculate centroids cluster-wise for the projection of individuals 
centroids <- aggregate(psiCars,list(cut),mean)[,2:(nd+1)] # take out 1st column = row labels


## Compute quality index
Bss <- sum(rowSums(centroids^2)*as.numeric(table(cut)))
Tss <- sum(rowSums(psiCars^2))
Ib <- 100*Bss/Tss


## Plot observations in 1st factorial plane
plottitle <- "Clustering of observations in PC1-2 factorial plane"

# compute index vector for 10% of observation tags: 'rownames(cars)'
labels_idx <- sample(1:nrow(cars),floor(.1*nrow(cars)),replace=F)
labels2 <- rep("",length(rownames(cars)))
labels2[labels_idx] <- rownames(cars)[labels_idx]

# add centroids' tags to labels
labels2 <- c(labels2,paste0("G",1:5))

# add centroids' factor levels to cut
cut2 <- c(cut,seq(1,NC))
names(cut2)[(length(names(cut2))-4):length(names(cut2))] <- paste0("G",1:NC)

plotdata <- data.frame(PC1=c(psiCars[,1],centroids[,1]),
                       PC2=c(psiCars[,2],centroids[,2]),
                       z=labels2)
pointType <- c(rep(16,nrow(cars)),rep(15,nrow(centroids)))
pointSize <- c(rep(1,nrow(cars)),rep(5,nrow(centroids)))

ggplot(data = plotdata,col=cut2+16) +
    theme_bw()+
    geom_vline(xintercept = 0, col="gray") +
    geom_hline(yintercept = 0, col="gray") +
    geom_text_repel(aes(PC1,PC2,label=labels2),
                    col= cut2+16,
                    size= 4,
                    point.padding= 0.5,
                    box.padding= unit(0.55, "lines"),
                    segment.size= 0.3,
                    segment.color= 'grey') +
    geom_point(aes(PC1,PC2),
               col= cut2+16,
               pch= pointType,
               size= pointSize) +
    labs(title= plottitle)+
    coord_fixed()

# OR, without centroids:
# compute index vector for 10% of observation tags: 'rownames(cars)'
labels_idx <- sample(1:nrow(cars),floor(.1*nrow(cars)),replace=F)
labels <- rep("",length(rownames(cars)))
labels[labels_idx] <- rownames(cars)[labels_idx]
plotdata <- data.frame(PC1=psiCars[,1],PC2= psiCars[,2],z=labels)

ggplot(data = plotdata,col=cut+16) +
    theme_bw()+
    geom_vline(xintercept = 0, col="gray") +
    geom_hline(yintercept = 0, col="gray") +
    geom_text_repel(aes(PC1,PC2,label = labels),
                    col=cut+16,
                    size=4,
                    point.padding = 0.5,
                    box.padding = unit(0.55, "lines"),
                    segment.size = 0.3,
                    segment.color = 'grey') +
    geom_point(aes(PC1,PC2),col= cut+16, pch= 16, size= 1) +
    labs(title = plottitle)+
    coord_fixed()


## Compute k-means
kmeanCars <- kmeans(psiCars,centers=centroids)
kmeanCars$cluster

# Quality index after consolidation
Bss <- sum(rowSums(kmeanCars$centers^2)*kmeanCars$size)  # kmeanCars$betweenss
Wss <- sum(kmeanCars$withinss)                           # kmeanCars$tot.withinss
Ib_consol <- 100*Bss/(Bss+Wss)

# Plot
par(mfrow=c(1,1),new=F)
plot(psiCars[,1],psiCars[,2],
     xlab='PC1',ylab='PC2',
     pch=16,
     type="p",
     col=cut+16,
     main="Consolidated clustering of observations in 5 classes"
)
points(centroids,pch=15,type='p',col=16+seq(NC),cex= 1.8)
text(centroids,labels=paste0("G",1:NC),pos=1,cex=1.2)
abline(h=0,v=0,col="gray")

# Use silhouette to confirm clustering result
library("cluster")
sil <- silhouette(kmeanCars$cluster,distCars)
plot(sil, col=16+seq(NC),cex=2, main='Silhouette widths for consolidated clustering')

cat("Cluster sizes (after k-means consolidation:",kmeanCars$size,"\n")


# ############################################
## 6: Using the function catdes() interpret and name the obtained clusters
#     Represent clusters in the first factorial plane
# ############################################
# 'kmeanCars$cluster' below is the nrow(cars)-component col-vector indicating cluster factoring level 
# (1 to 5 in present case), i.e. to which cluster each observation belongs.

(catdesCars <- catdes(cbind(as.factor(kmeanCars$cluster),cars[,1:16]),
                      1,           # index of the variable to characterized, i.e. 'kmeanCars$cluster'
                      proba=0.01,  # significance threshold considered to characterize category
                      row.w=NULL))
# Visualization
catdesCars$category$`1`[1:6,4]  #  p-values for cluster 1
catdesCars$category$`2`[1:6,4]  #  p-values for cluster 2
catdesCars$category$`3`[1:6,4]  #  p-values for cluster 3
catdesCars$category$`4`[1:6,4]  #  p-values for cluster 4
catdesCars$category$`5`[1:6,4]  #  p-values for cluster 5