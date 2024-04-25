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


// Define channels
Channel.fromFilePairs("${params.reads}", flat: true)
       .set { inputFastq }

// Define workflow
workflow {
  
  FastQC(inputFastq)
  Fastp(inputFastq)
  curlKrakenDB()  
  Kraken2(Fastp.out.trimmedReads, curlKrakenDB.out.krakenDb)  
  ExtractKrakenReads(Fastp.out.trimmedReads.combine(Kraken2.out.krakenOutputs, by: 0))
  rcorrector(ExtractKrakenReads.out.filteredReads)
  FastQC_2(rcorrector.out.rcorrectReads)
  ConcatenateReads(rcorrector.out.rcorrectReads)
  Trinity(ConcatenateReads.out.concatenatedReads)
  Evigene(Trinity.out.trinityFasta)
  Trinity_stats(Trinity.out.trinityFasta, Evigene.out.annotated_okay_fasta)
  BUSCO(Evigene.out.annotated_okay_fasta, Trinity.out.trinityFasta)
  //trinitymapping(Evigene.out.annotated_okay_fasta, rcorrector.out.rcorrectReads )
}

