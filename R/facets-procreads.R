procSnps <- function(rcmat, ndepth=35, het.thresh=0.25, snp.nbhd=250, gbuild="hg19", unmatched=FALSE, ndepthmax=5000) {
  #' heterozygous and keep flags of the SNPs
  #' @param rcmat input counts matrix
  #' @param ndepth (numeric) minimum normal sample depth to keep
  #' @param het.thresh (numeric) vaf threshold to call a SNP heterozygous
  #' @param snp.nbhd (logical) window size
  #' @param gbuild (character) genome build version.
  #' @param unmatched (logical)
  #' @param ndepthmax (numeric) loci for which normal coverage exceeds this number (default is 5000) will be discarded as PCR duplicates. Fof high coverage sample increase this and ndepth commensurately.
  #' @importFrom utils hasName
  #process SNPs,  keep only chromsomes 1-22 & X for humans and 1-19, X for mice
    if (gbuild %in% c("hg19", "hg38", "hg18")) {
        chromlevels <- c(1:22,"X")
    } else {
        chromlevels <- c(1:19,"X")
    }
    chr.keep <- rcmat$Chromosome %in% chromlevels
    # keep only snps with normal read depth between ndepth and 1000
    depthN.keep <- (rcmat$NOR.DP >= ndepth) & (rcmat$NOR.DP < ndepthmax)
    # reduce the data frame to these snps
    rcmat <- rcmat[chr.keep & depthN.keep,]
    # output data frame
    out <- list()
    out$chrom <- rcmat$Chromosome
    out$maploc <- rcmat$Position
    out$rCountT <- rcmat$TUM.DP
    out$rCountN <- rcmat$NOR.DP
    # if count matrix has unmatched normal as well include it
    if (hasName(rcmat, "UMN.DP")) out$umNrCount <- rcmat$UMN.DP
    out$vafT <- 1 - rcmat$TUM.RD/rcmat$TUM.DP
    out$vafN <- 1 - rcmat$NOR.RD/rcmat$NOR.DP
    # make chromosome ordered and numeric
    out$chrom <- as.numeric(ordered(out$chrom, levels=chromlevels))
    # call a snp heterozygous if min(vafN, 1-mafN) > het.thresh
    if (unmatched) {
        if (het.thresh == 0.25) het.thresh <- 0.1
        out$het <- 1*(pmin(out$vafT, 1-out$vafT) > het.thresh & out$rCountT >= 50)
    } else {
        out$het <- 1*(pmin(out$vafN, 1-out$vafN) > het.thresh)
    }
    # scan maploc for snps that are close to one another (within snp.nbhd bases)
    # heep all the hets (should change if too close) and only one from a nbhd
    out$keep <- scanSnp(out$maploc, out$het, snp.nbhd)
    as.data.frame(out)
}

procXSnps <- function(pileup, ndepth=35, het.thresh=0.25, snp.nbhd=250, gbuild="hg19", unmatched=FALSE, ndepthmax=5000, nhet=10) {
  #' Takes a snp-pileup file and determines sex of sample and any unmatched normals based on number of chrX het SNPs, as males should not have het X
  #' @param pileup (character) A snp-pileup generated pileup file that has been analyzed with readSnpMatrix(). Expect columns "Chromosome", "Position", "NOR.DP", "NOR.RD", "TUM.DP", and "TUM.RD". Can be a pileup file that has been merged with common loci of reference normals processed with PreProcSnpPileup()
  #' @param ndepth (numeric) minimum normal sample depth to keep
  #' @param het.thresh (numeric) vaf threshold to call a SNP heterozygous
  #' @param snp.nbhd (logical) window size
  #' @param gbuild (character) genome build version.
  #' @param unmatched (logical)
  #' @param ndepthmax (numeric) loci for which normal coverage exceeds this number (default is 5000) will be discarded as PCR duplicates. Fof high coverage sample increase this and ndepth commensurately.
  #' @param nhet (numeric) minimum number of heterzygous SNPs to classify sample as Female
  #' @return output a table of samples analyzed and imputed sex.
  #' @export

    chromlevels = "X"
    chr.keep <- pileup$Chromosome %in% chromlevels
    # keep only snps with normal read depth between ndepth and 1000
    depthN.keep <- (pileup$NOR.DP >= ndepth) & (pileup$NOR.DP < ndepthmax)
    # reduce the data frame to these snps
    rcmatX <- pileup[chr.keep & depthN.keep,]
    # output data frame
    out <- list()
    out$chrom <- rcmatX$Chromosome
    out$maploc <- rcmatX$Position


    out$rCountT <- rcmatX$TUM.DP
    out$rCountN <- rcmatX$NOR.DP
    out$vafT <- 1 - rcmatX$TUM.RD/rcmatX$TUM.DP
    out$vafN <- 1 - rcmatX$NOR.RD/rcmatX$NOR.DP
    out = as.data.frame(out)

    normCount = length(grep("^File([3-9]|[1-9]{2,})DP$", colnames(rcmatX)))
    RefnormCount = length(grep("^RefFile([0-9]{1,})DP$", colnames(rcmatX)))
    
    for(i in 3:(3+normCount-1)){
        tempVAF = paste('File', i, "VAF", sep="")
        tempR = paste("File", i, "R", sep="")
        tempDP = paste("File", i, "DP", sep="")
        tempHET = paste("File", i, "DPhet", sep="")
        out[,tempVAF] = 1 - (rcmatX[,tempR]/rcmatX[,tempDP])
        out[,tempHET] =  1*(pmin(out[,tempVAF], 1-out[,tempVAF]) > het.thresh )
    }
   
    if (RefnormCount>0){
      for(i in 1:RefnormCount){
        tempVAF = paste('RefFile', i, "VAF", sep="")
        tempR = paste("RefFile", i, "R", sep="")
        tempDP = paste("RefFile", i, "DP", sep="")
        tempHET = paste("RefFile", i, "DPhet", sep="")
        out[,tempVAF] = 1 - (rcmatX[,tempR]/rcmatX[,tempDP])
        out[,tempHET] =  1*(pmin(out[,tempVAF], 1-out[,tempVAF]) > het.thresh )
      }
    }
    
    out$NOR.DPhet <- 1*(pmin(out$vafN, 1-out$vafN) > het.thresh)
    out.hets = out[,grep("het", colnames(out))]
    out.hets = as.data.frame(colSums(out.hets, na.rm = T))
    colnames(out.hets) = "numHet"
    out.hets$sampleSex = ifelse(out.hets$numHet>nhet,"Female", "Male")
    rownames(out.hets) = gsub("het", "", rownames(out.hets))

    out.hets
}

scanSnp <- function(maploc, het, nbhd) {
    n <- length(maploc)
    zzz <- .Fortran("scansnp",
                    as.integer(n),
                    as.double(maploc),
                    as.double(het),
                    keep=double(n),
                    as.double(nbhd))
    zzz$keep
}

counts2logROR <- function(mat, gbuild, unmatched=FALSE, MandUnormal=FALSE, f, spanT, spanA, spanX) {
  #' obtain logR and logOR from read counts and GC-correct logR
  #' @param mat input data
  #' @param gbuild e.g. "hg19"
  #' @param unmatched (logical)
  #' @param MandUnormal analyzing both matched and unmatched normal for log ratio normalization
  #' @param f default span value for loess
  #' @param spanT span value tumor
  #' @param spanA span value autosomes
  #' @param spanX span value X
  #' @importFrom pctGCdata getGCpct
    out <- mat[mat$keep==1,]
    #out$chrom = gsub('X', '23', out$chrom) #testing replace X with 23

    # gc percentage
    out$gcpct <- rep(NA_real_, nrow(out))
    # get GC percentages from pctGCdata package
    # loop thru chromosomes
    #nchr <- max(mat$chrom) # IMPACT doesn't have X so only 22

    for (i in c(1:23)) {
   # for (i in 1:nchr) {
        ii <- which(out$chrom==i)
        # allow for chromosomes with no SNPs i.e. not targeted
        if (length(ii) > 0) {
            out$gcpct[ii] <- getGCpct(i, out$maploc[ii], gbuild)
        }

    }
    out = out[which(!is.na(out$gcpct)),]
    x.idx <- grep("X|23",out$chrom)
    ##### log-ratio with gc correction and maf log-odds ratio steps
    chrom <- out$chrom
    maploc <- out$maploc
    if (hasName(mat, "umNrCount")) {
        rCountN <- out$umNrCount
    } else {
        rCountN <- out$rCountN
    }
    rCountT <- out$rCountT
    vafT <- out$vafT
    vafN <- out$vafN
    het <- out$het
    gcpct <- out$gcpct
    gcpct.auto = gcpct[-x.idx]
    gcpct.x = gcpct[x.idx]

    # compute gc bias
    ncount <- tapply(rCountN, gcpct, sum)
    tcount <- tapply(rCountT, gcpct, sum)
    pctgc <- as.numeric(names(ncount))
    tscl <- sum(ncount)/sum(tcount)
    gcb <- lowess(pctgc, log2(tcount*tscl)-log2(ncount), f=f)
    jj <- match(gcpct, gcb$x)
    gcbias <- gcb$y[jj]
    # compute cn log-ratio (gc corrected) and baf log odds-ratio
    #####################################
    #square root transform count vectors.
    tumor_sqrt = sqrt(rCountT)
    tumor_sqrt.auto = tumor_sqrt[-x.idx]
    tumor_sqrt.x    = tumor_sqrt[x.idx]

    normal_sqrt     = sqrt(rCountN)
    normal_sqrt.auto = normal_sqrt[-x.idx]
    normal_sqrt.x    = normal_sqrt[x.idx]

    #loess regression for lr tumor autosomes and X seperately.
    loess_tumor.auto = lowess(gcpct.auto,tumor_sqrt.auto, f=spanT) #need to change this to input value from span.fits
    jj=match(gcpct.auto, loess_tumor.auto$x)
    fit<-loess_tumor.auto$y[jj]
    #loess_tumor.auto <-loess(tumor_sqrt.auto~gcpct.auto,span=f);
   # temp<-predict(loess_tumor.auto);
    normalized_t.auto<-(tumor_sqrt.auto-fit+median(tumor_sqrt.auto))/(median(tumor_sqrt.auto[which(tumor_sqrt.auto != 0)]));

    loess_tumor.x <-lowess(gcpct.x,tumor_sqrt.x,f=spanT);
    jj=match(gcpct.x, loess_tumor.x$x)
    fit<-loess_tumor.x$y[jj]
    #temp<-predict(loess_tumor.x);
    normalized_t.x<-(tumor_sqrt.x-fit+median(tumor_sqrt.x))/(median(tumor_sqrt.x[which(tumor_sqrt.x != 0)]));

    tumor_rt = c(normalized_t.auto, normalized_t.x)

    #loess regression for lr normal autosomes and X seperately.
    loess_normal.auto <-lowess(gcpct.auto, normal_sqrt.auto,f=spanA);
   # temp<-predict(loess_normal.auto);
    jj=match(gcpct.auto, loess_normal.auto$x)
    fit<-loess_normal.auto$y[jj]
    normalized_n.auto<-(normal_sqrt.auto-fit+median(normal_sqrt.auto))/(median(normal_sqrt.auto[which(normal_sqrt.auto != 0)]));

    loess_normal.x <-lowess(gcpct.x,normal_sqrt.x,f=spanX);
    jj=match(gcpct.x, loess_normal.x$x)
    fit<-loess_normal.x$y[jj]
    #temp<-predict(loess_normal.x);
    normalized_n.x<-(normal_sqrt.x-fit+median(normal_sqrt.x))/(median(normal_sqrt.x[which(normal_sqrt.x != 0)]));

    normal_rt = c(normalized_n.auto, normalized_n.x)

    #calculate log2 ratios
    cnlr = log2(0.25+tumor_rt^2) - log2(0.25+normal_rt^2) #square to fix overcorrection of logR magnitude

    #####################################
    #use old method of cnlr calc if matched normal
    if (!MandUnormal) cnlr <- log2(1+rCountT*tscl) - log2(1+rCountN) - gcbias
    # minor allele log-odds ratio and weights
    rCountN <- out$rCountN # reset normal depth in case umNrCount exists
    lorvar <- valor <- rep(NA_real_, length(maploc))
    if (unmatched) {
        # read count matrix for odds ratio etc
        rcmat <- round(cbind(vafT[het==1]*rCountT[het==1], (1-vafT[het==1])*rCountT[het==1]))
        # folded log of Tukey (with 1/6 correction)
        valor[het==1] <- log(rcmat[,1]+1/6) - log(rcmat[,2]+1/6)
        # variance - approximation using delta method
        lorvar[het==1] <- 1/(rcmat[,1]+1/6) + 1/(rcmat[,2]+1/6)
    } else {
        # read count matrix for odds ratio etc
        rcmat <- round(cbind(vafT[het==1]*rCountT[het==1], (1-vafT[het==1])*rCountT[het==1], vafN[het==1]*rCountN[het==1], (1-vafN[het==1])*rCountN[het==1]))
        # log-odds-ratio (Haldane correction)
        valor[het==1] <- log(rcmat[,1]+0.5) - log(rcmat[,2]+0.5) - log(rcmat[,3]+0.5) + log(rcmat[,4]+0.5)
        # variance of log-odds-ratio (Haldane; Gart & Zweifel Biometrika 1967)
        lorvar[het==1] <- (1/(rcmat[,1]+0.5) + 1/(rcmat[,2]+0.5) + 1/(rcmat[,3]+0.5) + 1/(rcmat[,4]+0.5))
    }
    # put them together
    out$lorvar <- out$valor <- out$cnlr <- out$gcbias <- rep(NA_real_, nrow(out))
    out$gcbias <- gcbias
    out$cnlr <- cnlr
    out$valor <- valor
    out$lorvar <- lorvar
    out
}

############################################################################
PreProcSnpPileup <- function(filename, err.thresh=Inf, del.thresh=Inf,
                             is.Reference=FALSE, gbuild="hg19") {
  #' PreProcSnpPileup takes a snp-pileup generated pileup file and process it into a data frame format for downstream processing.
  #' @param filename (character) File path to snp-pileup generated pileup file.
  #' @param err.thresh (numeric) Error threshold to be used to filter snp-pileup data frame.
  #' @param del.thresh (numeric) Deletion threshold to be used to filter snp-pileup data frame.
  #' @param is.Reference (logical) Indicate whether the snp-pilep is Reference data.
  #' @param gbuild (character) genome build version.
  #' @return A data drame of pileup depth values filtered against del.thresh and err.thresh values.
  #' @export

  pileup <- read.csv(filename, stringsAsFactors=FALSE)
  # remove chr if present in Chrom
  if (pileup$Chromosome[1] == "chr1") {
    pileup$Chromosome <- gsub("chr", "", pileup$Chromosome)
  }
  if (gbuild %in% c("hg19", "hg38", "hg18")) chromlevels <- c(1:22,"X")
  if (gbuild %in% c("mm9", "mm10")) chromlevels <- c(1:19,"X")
  pileup <- pileup[which(pileup$Chromosome %in% chromlevels),]

  # if pileup data contains tumor and matched normal data, use those columns
  #  to filter against err.thresh and del.thresh
  if (!is.Reference) {
  err.columns <- colnames(pileup)[grep("^File[0-9]+E$", colnames(pileup))][1:2]
  del.columns <- colnames(pileup)[grep("^File[0-9]+D$", colnames(pileup))][1:2]

  # remove loci where errors and deletions exceed thresholds
  select.loci <- apply(
    cbind(apply(pileup[err.columns], 2, function(x) x<=err.thresh),
          apply(pileup[del.columns], 2, function(x) x<=del.thresh)),
    1, all)

  # select loci in pileup data and skip identifiers
  pileup.select <- pileup[select.loci,]
  }
  else {
    pileup.select <- pileup
  }

  # retain genomic coordinates
  pileup.select.key <- paste(pileup.select$Chromosome, pileup.select$Position, sep=":")

  # calculate total depth for each samples at all loci
  for(i in 1:((ncol(pileup.select)-4)/4)){
    temp <- paste0("File", i, "DP")
    tempR <- paste0("File", i, "R")
    tempA <- paste0("File", i, "A")
   # tempRD <-paste0("File", i, "RD")
    pileup.select[,temp] <- pileup.select[,tempR] + pileup.select[,tempA]
   # pileup.select[,tempRD] <- pileup.select[,tempR]
  }
  pileup.select<- cbind(key=pileup.select.key,
                        pileup.select)
  
  if (is.Reference) {
    colnames(pileup.select) = gsub("^File", "RefFile", colnames(pileup.select))
  }

  return(pileup.select)
}

###########################################################################
FindBestNormalParameters <- function(TumorLoess, TumorPileup,
                                     ReferenceLoess=NULL, ReferencePileup=NULL,
                                     MinOverlap=0.90, useMatchedX=FALSE) {
  #' FindBestNormalParameters takes takes a facets2n generated tumor loess object and snp-pileup generated pileup file, and optional similar files for reference normals, and returns the pileup data for the best normal for T/N CNLR.
  #' @param TumorLoess (matrix) A facets2n generated TumorLoess matrix with header and span values in the first row.
  #' @param TumorPileup (data frame) snp-pileup generated pileup data frame with sample columns that match with the TumorLoess object.
  #' @param ReferenceLoess (matrix) A ReferenceLoess matrix with a header and span values in the first row.
  #' @param ReferencePileup (data frame) A snp-pileup generated pileup data frame with sample columns that match with the ReferenceLoess object.
  #' @param MinOverlap (numeric) A numeric between 0 and 1 that denotes the fraction overlap of loci between TumorLoess and the optional ReferenceLoess
  #' @param useMatchedX (logical) Force select matched normal for normalization in ChrX.
  #' @return A list of data frame with pileup depth values of Tumor, matched Normal, and a best unmatched normal, and the associated span values.
  #' @export

  TumorLoess.span <- TumorLoess[1,]
  TumorLoess <- as.data.frame(TumorLoess[-1,])
  colnames(TumorLoess)[1] <- "key"

  if (!is.null(ReferencePileup)) {
   
    ReferenceLoess.span <- ReferenceLoess[1,]
    ReferenceLoess <- as.data.frame(ReferenceLoess[-1,])
    colnames(ReferenceLoess)[1] <- "key"

    common.loci <- intersect(ReferenceLoess$key, TumorLoess$key)
    if (length(common.loci) / max(length(TumorLoess$key),
                                  length(ReferenceLoess$key)) < MinOverlap ) {
      warning(sprintf("Overlap of loci between the two Loess dataframes\
           is less than defined MinOverlap fraction of %s\n", MinOverlap))

    }
    combined.loess <- cbind(
      TumorLoess[which(TumorLoess$key %in% common.loci),],
      ReferenceLoess[which(ReferenceLoess$key %in% common.loci),][,-1]
    )
    TumorPileup.common = TumorPileup
    TumorPileup.common = TumorPileup.common[which(TumorPileup.common$key %in% common.loci),]
    TumorPileup.common$NOR.DP <- TumorPileup.common$File1R + TumorPileup.common$File1A
    TumorPileup.common$NOR.RD <- TumorPileup.common$File1R
    TumorPileup.common$TUM.DP <- TumorPileup.common$File2R + TumorPileup.common$File2A
    TumorPileup.common$TUM.RD <- TumorPileup.common$File2R
    
    ReferencePileup.common = ReferencePileup[which(ReferencePileup$key %in% common.loci),]
  
    colkeep = colnames(TumorPileup.common)[grep("File([3-9]|[1-9]{2,})", colnames(TumorPileup.common))]
    combined.pileup <- cbind(
      TumorPileup.common[,c(colkeep,"File1DP", "NOR.DP", "NOR.RD", "TUM.DP", "TUM.RD")],
      ReferencePileup.common
    )

    combined.span <- c(TumorLoess.span, ReferenceLoess.span[-1])
  }
  else {
    combined.pileup <- TumorPileup
    combined.pileup$NOR.DP <- combined.pileup$File1R + combined.pileup$File1A
    combined.pileup$NOR.RD <- combined.pileup$File1R
    combined.pileup$TUM.DP <- combined.pileup$File2R + combined.pileup$File2A
    combined.pileup$TUM.RD <- combined.pileup$File2R
    
    combined.loess <- TumorLoess
    combined.span <- TumorLoess.span
    common.loci <- TumorLoess$key
  }

  # Assumptions: 
    # First column of data is the key,
    # Second column belongs to the Normal sample
    # Third column belongs to the Tumor sample
    #remaining columns are unmatched normals samples
  
  MatchedNormalIdentifier <- colnames(combined.loess)[2]
  TumorIdentifier <- colnames(combined.loess)[3]

  #identify probes on ChrX for separate processing
  x.idx <- as.vector(grep('^X\\:', combined.loess$key))
  x.idx.values <- as.vector(grep('^X\\:', combined.loess$key, value = T))

  #determine sex of sample and unmatched nornmals
  snpsX = procXSnps(combined.pileup, nhet=10)
  sampleSex = snpsX["NOR.DP", "sampleSex"]
  message("imputed patient sex: ", sampleSex)

  #calculate noise of tumor against normals for autosomes and ChrX seperately
  noiseAuto <- do.call('rbind',list(apply(combined.loess[-x.idx,-c(1,3), drop=F],2,function(column){
    lr = log2(as.numeric(levels(combined.loess[-x.idx,3]))[combined.loess[-x.idx,3]]) -
      log2(as.numeric(column))
    return(sum(lr^2, na.rm=T));
  })));

  #pick the normals that minimize noise
  best_normAuto <- colnames(noiseAuto)[which(noiseAuto == min(noiseAuto) & noiseAuto != 0)][1]
  if(useMatchedX) {
    best_normX <- MatchedNormalIdentifier
  }
  else {
    #limit normals for X normalization to those matching patient sex
    combined.loess.useX = row.names(snpsX[which(snpsX$sampleSex==sampleSex),])
    combined.loess.useX = gsub("NOR.DP", "File1DP", combined.loess.useX)

    noiseX <- do.call('rbind',list(apply(subset(combined.loess[x.idx,-c(1,3), drop=F],select = c(combined.loess.useX)),2,function(column){
      lr = log2(as.numeric(levels(combined.loess[x.idx,3]))[combined.loess[x.idx,3]]) -
        log2(as.numeric(column))
      return(sum(lr^2, na.rm=T));
    })));

    best_normX <- colnames(noiseX)[which(noiseX == min(noiseX) & noiseX != 0)][1]
  }

  message(sprintf("Best normal for autosomes: %s\nBest normal for ChrX: %s\n",
                  best_normAuto, best_normX))
  
  rcmat <- cbind(combined.pileup[,c("Chromosome", "Position", "NOR.DP", "NOR.RD", "TUM.DP", "TUM.RD")],
            UMN.DP=c(combined.pileup[-x.idx, best_normAuto], combined.pileup[x.idx,best_normX]))
  
  return(list("rcmat"=rcmat,
            "spanT"=as.numeric(combined.span[TumorIdentifier]), # Assume that tumor data is always in the third column as expected
            "spanA"=as.numeric(combined.span[best_normAuto]),
            "spanX"=as.numeric(combined.span[best_normX])
            )
        )
}

######################################################################
MakeLoessObject <- function(pileup, write.loess=FALSE, outfilepath="./loess.txt", is.Reference = FALSE, gbuild="hg19") {

  #' MakeLoessObject takes a pipleup file generated by snp-pileup and generates a loess/lowess object, which is also optinally written into an output file.
  #' @importFrom pctGCdata getGCpct
  #' @importFrom utils write.table
  #' @param pileup (data frame) A data franme of snp-pileup generated depth.
  #' @param write.loess (logical) Write loess object into file, instead of returning it as a matrix?
  #' @param outfilepath (character) Filepath for writing loess object.
  #' @param is.Reference (logical) Indicate whether the snp-pilep is Reference data.
  #' @param gbuild (character) genome build version.
  #' @return A dataframe of loess normalized values for all input samples against filtered loci or None, if the loess normalized value is to be written to an output file.
  #' @export

  # read pileup data and select rows based on used-defined err and del thresholds
  pileup.select <- pileup

  pileup.select.dp <- pileup.select[,grep(paste(c("^key$", "^Chromosome$", "^Position$", "File.*DP$"),collapse="|"), colnames(pileup.select))]
  
  if (is.Reference) {
    message("starting loess normalization for reference samples")
    #pileup.select.dp$medianDP<- apply(pileup.select.dp[,grep("RefFile.*DP", colnames(pileup.select.dp))], 1, median, na.rm=T)
    #pileup.select.dp$q25<- apply(pileup.select.dp[,grep("RefFile.*DP", colnames(pileup.select.dp))], 1, quantile, probs=0.25, na.rm=T)
    #pileup.select.dp <- pileup.select.dp[which(pileup.select.dp$q25>quantile(pileup.select.dp$medianDP, 0.1)),]
    #pileup.select.dp <- subset(pileup.select.dp, select=-c(q25, medianDP))
  }
  else {
    #message("skipping quantile covg filtering")
    #pileup.select.dp$medianDP<- apply(pileup.select.dp[,grep("File([1]|[3-9]|[1-9]{2,})DP$", colnames(pileup.select.dp))][,-c(2), drop=F], 1, median, na.rm=T)
    #pileup.select.dp$q25<- apply(pileup.select.dp[,grep("File([1]|[3-9]|[1-9]{2,})DP$", colnames(pileup.select.dp))][,-c(2), drop=F], 1, quantile, probs=0.25, na.m=T)
    #pileup.select.dp <- pileup.select.dp[which(pileup.select.dp$q25>quantile(pileup.select.dp$medianDP, 0.1)),]
    #pileup.select.dp <- subset(pileup.select.dp, select=-c(q25, medianDP))
  }

  gcout <- subset(pileup.select.dp, select=c(Chromosome, Position))
  gcout$gcpct <- rep(NA_real_, nrow(gcout))

  for (i in c(1:22,'X')) {
    ii <- which(gcout$Chromosome==i)
    if (length(ii) > 0) {
      gcout$gcpct[ii] <- getGCpct(i, gcout$Position[ii], gbuild)
    }
  }
  gcout$key <-  paste(gcout$Chromosome, gcout$Position, sep = ":")

  #remove positions near centromeres, where we don't calculate GCpct
  gcout <-gcout[!is.na(gcout$gcpct),]
  #subset counts dfs to those with gc calc
  pileup.select.dp <- pileup.select.dp[which(pileup.select.dp$key %in% gcout$key),]

  #add gcpct values to the count file
  pileup.select.dp$gcpct<-gcout[match(pileup.select.dp$key, gcout$key),"gcpct"]

  gc.bias <- pileup.select.dp$gcpct
  
  #determine span values for lowess normalization
  span.fits <- do.call('rbind',list(
    apply(subset(pileup.select.dp, select= -c(Chromosome, Position, key, gcpct)),2,function(column){
    column_sqrt<-sqrt(column)
    testspan <- function(spanvalue){  #change this to get span values seperately for auto, X?
      loess.obj<-lowess(gc.bias, column_sqrt,f=spanvalue);
      jj <- match(pileup.select.dp$gcpct, loess.obj$x)
      fit <- loess.obj$y[jj]#Calculation of the loess fit for each spanvalue
      normalized<-column_sqrt-fit+median(column_sqrt) #Data normalized for each spanvalue

      loess.obj2<-lowess(gc.bias,normalized,f=spanvalue);
      fit2 <- loess.obj2$y  #The "fit" of each normalized data point - the result gives the flat-ish line
      spanvar <- var(fit2,na.rm=TRUE) #Calculate the variance to find the flattest line after fitting
      return(round(spanvar,5));
    }
    optimize.obj <-	optimize(testspan,interval=c(0.1,0.9),maximum=F);  #change to 0.2, 0.8?
    return(c('min'=optimize.obj$minimum,'obj'=optimize.obj$objective));
  })));

  span.fits <- t(span.fits)

  pileup.select.dp.lowess <- do.call('cbind',lapply(seq(1,ncol(pileup.select.dp)-4,1),function(i){
    column_sqrt <- sqrt(pileup.select.dp[,grep("File.*DP", colnames(pileup.select.dp))][,i])
    loess.obj <-lowess(gc.bias, column_sqrt,f=span.fits[i,'min']);
    jj <- match(pileup.select.dp$gcpct, loess.obj$x)
    fit <- loess.obj$y[jj]
    normalized <- (column_sqrt-fit+median(column_sqrt))/(median(column_sqrt[which(column_sqrt != 0)]));
    return(normalized);
  }));

  colnames(pileup.select.dp.lowess) <- setdiff(
    colnames(pileup.select.dp), c("Chromosome", "Position", "key", "gcpct"))

  pileup.select.dp.lowess <- cbind(key=paste0(pileup.select.dp$Chromosome, ":",
                                  pileup.select.dp$Position), pileup.select.dp.lowess)

  # add span values as the first row
  pileup.select.dp.lowess <- rbind(c("span", span.fits[,"min"]),as.matrix(pileup.select.dp.lowess))

  if(write.loess) {
    write.table(pileup.select.dp.lowess, file=outfilepath, sep="\t", quote=F, col.names=T, row.names=F)
  }
  else {
    return(pileup.select.dp.lowess)
  }
}
