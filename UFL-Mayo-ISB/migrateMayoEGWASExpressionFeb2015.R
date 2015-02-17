require(synapseClient)
synapseLogin()

##query master table for emory files
#mayoTable <- synTableQuery('SELECT * FROM syn3163713 where data like \'mayo%\' and migrator=\'Ben\' and toBeMigrated=TRUE',loadResult = TRUE)
migrateMayoArray <- function(i,newFileName,newEntityName,other,tissueType){
  mayoTable <- synTableQuery('SELECT * FROM syn3163713 where data like \'MayoCC Expression Array%\' and migrator=\'Ben\' and toBeMigrated=TRUE',loadResult = TRUE)
  normalized <- synGet(mayoTable@values$originalSynapseId[i])
  system(paste('cp ',normalized@filePath,' ',newFileName,sep=''))
  
  b <- File(newFileName,parentId=mayoTable@values$newParentId[i],name=newEntityName)
  dataAnnotation <- list(
    dataType = 'mRNA',
    consortium = 'AMP-AD',
    disease = c('Alzheimers Disease', 'Control'),
    tissueType = tissueType,
    platform= 'IlluminaWholeGenomeDASL',
    center = 'UFL-Mayo-ISB',
    study = 'MayoEGWAS',
    fileType = 'tsv',
    organism = 'Homo sapiens'
  )
  synSetAnnotations(b) <- dataAnnotation
  act <- Activity(name='Mayo EGWAS Expression Array Data Migration',
                  used=list(list(entity=mayoTable@values$originalSynapseId[i],wasExecuted=F)),
                  executed=list("https://github.com/Sage-Bionetworks/ampAdScripts/blob/master/UFL-Mayo-ISB/migrateMayoEGWASExpressionFeb2015.R"))
  act <- storeEntity(act)
  generatedBy(b) <- act
  b <- synStore(b)
  mayoTable@values$newSynapseId[i] <- b$properties$id
  wind <- is.na(mayoTable@values$newSynapseId)
  if(sum(wind)>0){
    mayoTable@values$newSynapseId[wind] <- ''
  }
  mayoTable@values$newFileName[i] <- ''
  mayoTable@values$isMigrated[i] <- TRUE
  mayoTable@values$hasAnnotation[i] <- TRUE
  mayoTable@values$hasProvenance[i] <- TRUE
  mayoTable <- synStore(mayoTable)
  system(paste0('rm ',newFileName))
}


migrateMayoArray(1,'AMP-AD_MayoEGWAS_UFL-Mayo-ISB_IlluminaWholeGenomeDASL_Cerebellum.txt','MayoEGWAS_UFL-Mayo-ISB_IlluminaWholeGenomeDASL_Cerebellum',tissueType = 'Cerebellum')

migrateMayoArray(2,'AMP-AD_MayoEGWAS_UFL-Mayo-ISB_IlluminaWholeGenomeDASL_TemporalCortex.txt','MayoEGWAS_UFL-Mayo-ISB_IlluminaWholeGenomeDASL_TemporalCortex',tissueType = 'Temporal Cortex')





