#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Import modules
include { FastQC } from './modules/fastqc.nf'
include { Fastp } from './modules/fastp.nf'
include { Kraken2 } from './modules/kraken.nf'
include { curlKrakenDB } from './modules/curlkraken.nf'
include { ExtractKrakenReads } from './modules/filter_kraken.nf'
include { rcorrector } from './modules/rcorrector.nf'
include { FastQC_2 } from './modules/fastqc2.nf'
include { ConcatenateReads } from './modules/concatanate.nf'
include { Trinity } from './modules/trinityassembly.nf'
include { Evigene } from './modules/evigene.nf'
include { Trinity_stats } from './modules/trinitystats.nf'
include { BUSCO } from './modules/busco.nf'
include { trinitymapping } from './modules/trinitymapping.nf'
include { RSEM } from './modules/rsem.nf'
include { blastdb } from './modules/blastdb.nf'
include { blastp } from './modules/blastp.nf'
include { UPIMAPI } from './modules/upimapi.nf'

// Define channels
Channel.fromFilePairs("${params.reads}", flat: true)
       .set { inputFastq }

// Define workflow
workflow {
  
    // Preprocessing on raw-reads
  FastQC(inputFastq)
  Fastp(inputFastq)
  curlKrakenDB()  
  Kraken2(Fastp.out.trimmedReads, curlKrakenDB.out.krakenDb)  
  ExtractKrakenReads(Fastp.out.trimmedReads.combine(Kraken2.out.krakenOutputs, by: 0))
  rcorrector(ExtractKrakenReads.out.filteredReads)
  FastQC_2(rcorrector.out.rcorrectReads)

    // Collect all *_1.cor.fq.gz and *_2.cor.fq.gz files
  rcorrectRead1Channel = rcorrector.out.rcorrectReads.flatMap { it[1] }.collect()
  rcorrectRead2Channel = rcorrector.out.rcorrectReads.flatMap { it[2] }.collect()

   // de-novo transcriptome assembly and quality assessment
  ConcatenateReads(rcorrectRead1Channel, rcorrectRead2Channel)
  Trinity(ConcatenateReads.out.concatenatedRead1, ConcatenateReads.out.concatenatedRead2, params.SPECIES_IDENTIFIER)
  Evigene(Trinity.out.trinityFasta)
  Trinity_stats(Trinity.out.trinityFasta, Evigene.out.annotated_okay_fasta)
  BUSCO(Evigene.out.annotated_okay_fasta, Trinity.out.trinityFasta)

   // Differential gene expression analysis
 trinitymapping(Evigene.out.annotated_okay_fasta, Trinity_stats.out.okay_trans_map, rcorrector.out.rcorrectReads)
 RSEM(Evigene.out.annotated_okay_fasta, trinitymapping.out.rsem_dir, Trinity_stats.out.okay_trans_map, trinitymapping.out.isoforms, params.metadata)
 
   // Blast and annotations
  blastdb()
  blastp(Evigene.out.annotated_okay_aa, blastdb.out.blastdb_paths, params.SPECIES_IDENTIFIER)
  UPIMAPI(blastp.out.blastp_out, params.SPECIES_IDENTIFIER)
}
