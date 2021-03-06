#===============================================================================
#       Load libraries
#===============================================================================

library(DESeq2)
library("BiocParallel")
register(MulticoreParam(12))
library(ggplot2)
library(Biostrings)
library(devtools)
load_all("myfunctions") # this contains various R scripts for plotting graphs
library(data.table)
library(dplyr)
library(naturalsort)
library(tibble)

#===============================================================================
#       Load features counts data 
#===============================================================================

# load tables into a list of data tables - "." should point to counts directory, e.g. "counts/."
qq <- lapply(list.files(".",".*.txt$",full.names=T,recursive=F),function(x) fread(x))

# rename the sample columns (7th column in a feature counts table, saved as the path to the BAM file)
# in the below I'm saving the 10th ([[1]][10]) path depth (which is the informative part of the file name)
invisible(lapply(seq(1:length(qq)), function(i) colnames(qq[[i]])[7]<<-strsplit(colnames(qq[[i]])[7],"\\/")[[1]][10]))

# merge the list of data tables into a single data table
m <- Reduce(function(...) merge(..., all = T,by=c("Geneid","Chr","Start","End","Strand","Length")), qq)
colnames(m) <- sub("\\.Aligned.*","",colnames(m))
# output "countData"
write.table(m[,c(1,7:(ncol(m))),with=F],"countData",sep="\t",na="",quote=F,row.names=F) 
# output gene details
write.table(m[,1:6,with=F],"genes.txt",sep="\t",quote=F,row.names=F) 

#==========================================================================================
#       Read pre-prepared colData,  countData and annotations
##=========================================================================================

colData <- read.table("colData",header=T,sep="\t")
# colData$condition <- rep(c("02780","02793","F55","10170","MWT","MOL","MKO","TJ"),3) # need to test this - will set columns to numbers 
countData <- read.table("countData",sep="\t",header=T,row.names=1) # produced above, could just subset the data table countData <- m[,c(1,7:length(m),with=F]	
countData <- countData[,as.character(colData$Sample_ID)] # reorder countData columns to same order as colData rows

# annotations <- fread("WT_annotation.tsv")
# annotations$query_id <- sub("\\.t*","",annotations$query_id) # remove .t1 from annotation gene names

	
#===============================================================================
#       DESeq2 analysis
#		Set alpha to the required significance level. This also effects how
#		DESeq calculated FDR - setting to 0.05 and then extracting results with a
#		significance below 0.01 will give slightly different results form setting
#		alpha to 0.01
#================================================================================

dds <- 	DESeqDataSetFromMatrix(countData,colData,~1) 
sizeFactors(dds) <- sizeFactors(estimateSizeFactors(dds))
dds$groupby <- paste(dds$condition,dds$sample,sep="_")
#dds <- collapseReplicates(dds,groupby=dds$groupby)
design=~block+condition
design(dds) <- design # could just replace the ~1 in the first step with the design, if you really wanted to...
dds <- DESeq(dds,parallel=T)

# set the significance level for BH adjustment	    
alpha <- 0.05

# calculate the differences - uses the "levels" of the condition factor as the third term for the contrast
# res is a list object containing the DESeq results objects for each contrast
# contrast=c("condition","RH1","RH2") etc. (the below just runs through all of the different sample types (excluding RH1))
res <- lapply(c(1,3,4), function(i) results(dds,alpha=alpha,contrast=c("condition","control",levels(dds$condition)[i])))
# merge results with annotations
res.merged <- lapply(res,function(x) left_join(rownames_to_column(as.data.frame(x)),annotations,by=c("rowname"="query_id")))	
	
# get, then order the significant results
sig.res <- lapply(res.merged, function(x) subset(x,padj<=alpha))
sig.res <- lapply(sig.res,function(x) x[order(x$padj),])

	
# merged  merged
out <- res.merged[[1]][,c(1:2)]
invisible(lapply(res.merged,function(o) out<<-cbind(out,o[,c(3,7)])))
out <- cbind(out,res.merged[[1]][,8:16])
write.table(out,"all.merged.csv",sep=",",quote=F,na="",row.names=F)

# sig all		 
all.sig <- subset(out,P_02793<=0.05&P_F55<=0.05&P_10170<=0.05&P_MWT<=0.05&P_MOL<=0.05&P_MKO<=0.05&P_TJ<=0.05)		 
write.table(all.sig,"all.sig.csv",sep=",",quote=F,na="",row.names=F)
	
# write tables of results, and significant results
lapply(seq(1:7),function(x) {
	write.table(res.merged[[x]],paste(names(res.merged)[x],"merged.txt",sep="."),quote=F,na="",row.names=F,sep="\t")
	write.table(sig.res[[x]],paste(names(sig.res)[x],"sig.merged.txt",sep="."),quote=F,na="",row.names=F,sep="\t")
	write.table(all.sig[[x]],paste(names(all.sig)[x],"all.sig.merged.txt",sep="."),quote=F,na="",row.names=F,sep="\t")
})	
	
	
#===============================================================================
#       FPKM
#===============================================================================

rowRanges(dds) <- GRangesList(apply(m,1,function(x) GRanges(x[[1]],IRanges(1,as.numeric(x[[6]])),"+")))
myfpkm <- data.table(GeneID=m[,1],length=m[,6],fpkm(dds,robust=T))
write.table(myfpkm,"fpkm.txt",quote=F,na="",sep="\t")
	
#===============================================================================
#       Heirachical clustering
#===============================================================================

clus <- function(X,clusters=10,m=1,name="hclust.pdf") {
	if (m==1) {d <- dist(X, method = "manhattan")}
	else if (m==2) {d <- dist(X, method = "euclidean")}
	else if (m==3) {d <- dist(X, method = "maximum")}
	else if (m==4) {d <- dist(X, method = "canberra")}
	else if (m==5) {d <- dist(X, method = "binary")}
	else d <- {dist(X, method = "minkowski")}
	hc <- hclust(d, method="ward")
	groups <- cutree(hc, k=clusters) # cut tree into n clusters
	pdf(name,height=8,width=8)
	plot(hc)
	rect.hclust(hc,k=clusters)
	dev.off()
	return(list(hc,groups,d))
}

#===============================================================================
#       Graphs
#===============================================================================
	
# PCA 1 vs 2 plot
vst <- varianceStabilizingTransformation(dds,blind=F)
mypca <- prcomp(t(assay(vst)))
mypca$percentVar <- mypca$sdev^2/sum(mypca$sdev^2)
df <- t(data.frame(t(mypca$x)*mypca$percentVar))

pc.res <- resid(aov(mypca$x~vst@colData$block))				    
d <- t(data.frame(t(pc.res)*mypca$percentVar))
				    
pdf("AMF.pca.pdf",height=8,width=8)
plotOrd(df,vst@colData,design="condition",xlabel="PC1",ylabel="PC2", pointSize=3,textsize=14)
plotOrd(df,vst@colData,design="condition",shapes="block",xlabel="PC1",ylabel="PC2", pointSize=3,textsize=14)
plotOrd(d,vst@colData,design="condition",xlabel="PC1",ylabel="PC2", pointSize=3,textsize=14)
plotOrd(d,vst@colData,design="condition",shapes="block",xlabel="PC1",ylabel="PC2", pointSize=3,textsize=14)
dev.off()
				    
	
# MA plots	
pdf("MA_plots.pdf")
				    
lapply(res.merged,function(obj) {
	plot_ma(obj[,c(1:5,7]),xlim=c(-8,8))
})
dev.off()
