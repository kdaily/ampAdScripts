library(synapseClient)
library(rGithubClient)

synapseLogin()

## Get this script
thisRepo <- getRepo("Sage-Bionetworks/ampAdScripts")
thisScript <- getPermlink(thisRepo, "Mount-Sinai/processHBTRCexpressionarray.R")

## Get files
alzFileId <- "syn2706445"
normFileId <- "syn2706448"
metaFileId <- "syn3157400"

alzfile <- synGet(alzFileId)
normfile <- synGet(normFileId)
metafile <- synGet(metaFileId)

## Get info about where they go
q <- "SELECT * FROM syn3163713 where data like 'HBTRC%'"
res <- synTableQuery(q)

newExprParentId <- subset(res@values, originalSynapseId == normFileId)$newParentId
newMetaParentId <- subset(res@values, originalSynapseId == metaFileId)$newParentId

## Load files
alzdata <- read.delim(alzfile@filePath, check.names=FALSE)
normdata <- read.delim(normfile@filePath, check.names=FALSE)
metadata <- read.delim(metafile@filePath)

## Get meta cols
## I know by manual inspection that they are the first 10 cols
alzmetacolnames <- colnames(alzdata)[1:10]
normmetacolnames <- colnames(normdata)[1:10]

# Check that they're the same
all(alzmetacolnames == normmetacolnames)

# And check that they're in the same order based on reporterid
all(alzdata$reporterid == normdata$reporterid)

## Get sample cols - the rest of the columns
alzsamplecolnames <- colnames(alzdata)[11:ncol(alzdata)]
normsamplecolnames <- colnames(normdata)[11:ncol(normdata)]

## Update metadata with disease state
##### After doing this, there are a number of samples not in the alz or normal files
##### They all have has.expression == FALSE, but some have genotyped == TRUE
metadata <- transform(metadata, DiseaseStatus=NA)
metadata$DiseaseStatus[match(alzsamplecolnames, metadata$TID)] <- "Alzheimer's"
metadata$DiseaseStatus[match(normsamplecolnames, metadata$TID)] <- "Control"
metadata <- transform(metadata, DiseaseStatus=factor(DiseaseStatus))

mergeddata <- cbind(alzdata[, alzmetacolnames],
                    alzdata[, alzsamplecolnames],
                    normdata[, normsamplecolnames])
colnames(mergeddata) <- gsub("^X", "", colnames(mergeddata))

consortium <- "AMP-AD"
study <- "HBTRC"
center <- "MSSM"
platform <- "Agilent44Karray"
other <- "PFC_AgeCorrected_all"
extension <- "tsv"
disease <- c("Alzheimer's Disease", "Control")
organism <- "human"
dataType <- "mRNA"
tissueType <- "Dorsolateral Prefrontal Cortex"
tissueTypeAbrv <- "PFC"

## write data
newdatafilename <- paste(paste(consortium, study, center, platform, other, sep="_"),
                         "tsv", sep=".")

write.table(mergeddata, file=newdatafilename, sep="\t", row.names=FALSE, quote=FALSE)

syndatafile <- File(newdatafilename, parentId=newExprParentId,
                name=paste(consortium, study, center, platform, other, sep="_"))

act <- Activity(name="Merge files", used=list(alzfile, normfile), executed=thisScript)
generatedBy(syndatafile) <- act

synSetAnnotations(syndatafile) <- list(consortium=consortium, study=study, center=center, platform=platform, 
                                       dataType=dataType, organism=organism, disease=disease, tissueType=tissueType,
                                       tissueTypeAbrv=tissueTypeAbrv, fileType="tsv")

o <- synStore(syndatafile)

## Update the table with info
res@values$newSynapseId[res@values$originalSynapseId %in% c(alzFileId, normFileId)] <- o@properties$id
res@values$newParentId[res@values$originalSynapseId %in% c(alzFileId, normFileId)] <- newExprParentId

## write metadata
dataType <- "Covariates"
extension <- "tsv"

newmetafilename <- paste(paste(consortium, study, center, platform, dataType, sep="_"),
                         "tsv", sep=".")

write.table(metadata, file=newmetafilename, sep="\t", row.names=FALSE, quote=FALSE)

synmetafile <- File(newmetafilename, parentId=newMetaParentId,
                name=paste(consortium, study, center, platform, dataType, sep="_"))

act <- Activity(name="Add disease status column", used=list(metafile, alzfile, normfile), executed=list(thisScript))
generatedBy(synmetafile) <- act

synSetAnnotations(synmetafile) <- list(consortium=consortium, study=study, center=center, platform=platform, 
                                       dataType=dataType, organism=organism, disease=disease, tissueTypeAbrv=tissueTypeAbrv,
                                       tissueType=tissueType, fileType="tsv")

o <- synStore(synmetafile)

## Update table with new info
## Update the table with info
res@values$newSynapseId[res@values$originalSynapseId %in% c(metaFileId)] <- o@properties$id
res@values$newParentId[res@values$originalSynapseId %in% c(metaFileId)] <- newMetaParentId

res <- synStore(res)