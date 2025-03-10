#' Estimate Lineage Proportions In Samples
#'
#' Create summary tables containing data on lineages identified in samples, including estimates of relative proportions of lineages and identities of associated characteristic mutations.
#' 
#' @param lineage.muts *(Required)* Path to csv file with cols "Gene", "Mutation", and  "Lineage" defining mutations associated with lineages of interest. See example file at "https://github.com/mikesovic/MixviR/blob/main/mutation_files/outbreak_20220217.csv". Additional columns will be ignored.
#' @param dates Path to optional csv file with cols "SAMP_NAME", "LOCATION", and "DATE". Sample names need to match those in *samp_mutations* data frame created by `call_mutations()`. Dates should be provided in the format *mmddyyyy*.
#' @param outfile.name If writing output to file, a character string giving the name/path of the file (csv) to be written.
#' @param min.alt.freq Minimum frequency (0-1) for mutation to be counted. Default = 0.01.
#' @param read.muts.from By default, data are read from the *samp_mutations* data frame created by `call_mutations()` and written to the global environment. If this data frame was written to a file (see *write.mut.table* in `call_mutations()`), the mutation data can be read in from that file by providing its path.  
#' @param scale Logical to indicate whether estimated proportions of lineages within a sample should be scaled down to sum to 1 if the sum of the initial estimates is > 1. Default = TRUE.
#' @param use.median Logical to define the metric used to estimate frequencies of lineages in samples. Default = FALSE (mean is used).
#' @param samps.to.inc Character vector of one or more sample names to include. If NULL (default), all samples are included.
#' @param locs.to.inc Character vector of one or more locations to include. If NULL (default), all locations are included. Applies only if a dates file is provided, and these locations must match those in the 'LOCATION' column of that file.
#' @param lineages.to.inc Character vector of one or more lineages to test for and report in results. If NULL (default), all lineages listed in the lineage.muts file are evaluated and reported.
#' @param report.all Logical indicating whether to report results for all lineages (TRUE), or just those with a proportion of mutations present that exceeds *presence.thresh*. Default FALSE.
#' @param presence.thresh Numeric (0-1) defining a proportion of characteristic mutations that must be present in the sample for a lineage to be considered present. This threshold is applied if *report.all* = FALSE (the default).
#' @param depths.from Character, one of "all" (default) or "characteristic". If "all", average sequencing depths are calculated based on all mutations in a sample. If "characteristic", mean depths are calculated from the set of mutations that occur in only one analyzed lineage (mutations shared by two or more lineages are filtered out prior to calculating depths).
#' @keywords lineage proportions
#' @return Data frame containing estimates of proportions of each lineage in the sample.
#' @export
#' @examples
#' estimate_lineages(lineage.muts = system.file("extdata", 
#'                                              "example_lineage_muts.csv", 
#'                                              package = "MixviR"), 
#'                   read.muts.from = system.file("extdata", 
#'                                                "sample_mutations.tsv", 
#'                                                package = "MixviR"))

estimate_lineages <- function(min.alt.freq = 0.01,
                          dates = NULL, 
                          lineage.muts = NULL, 
                          read.muts.from = NULL,
                          scale = TRUE,
                          use.median = FALSE,
                          outfile.name = NULL,
                          presence.thresh = 0.5,
                          samps.to.inc = NULL,
                          locs.to.inc = NULL,
                          lineages.to.inc = NULL,
                          report.all = FALSE,
                          depths.from = "all") {
  
  #determine where to read input data from - either 'samp_mutations' object in global env. or file
  if (is.null(read.muts.from)) {
    samp_data <- samp_mutations %>%
      dplyr::select(SAMP_NAME, CHR, POS, GENE, ALT_ID, AF, DP) 
  } else {
    samp_data <- readr::read_tsv(read.muts.from, show_col_types = FALSE) %>%
      dplyr::select(SAMP_NAME, CHR, POS, GENE, ALT_ID, AF, DP) 
  }
  
  #read in lineage-characteristic mutations
  lineage_muts <- readr::read_csv(lineage.muts, 
                                  col_types = readr::cols_only(Gene = readr::col_character(),
                                                                             Mutation = readr::col_character(),
                                                                             Lineage = readr::col_character())) %>%
    tidyr::unite("ALT_ID",
                 Gene, Mutation,
                 sep = "_") 
  
  #identify & flag mutations that are shared by more than one lineage
  duplicated <- lineage_muts$ALT_ID[duplicated(lineage_muts$ALT_ID)]
  
  lineage_muts <- lineage_muts %>%
    dplyr::mutate("characteristic" = ifelse(!ALT_ID %in% duplicated, "Y", "N"))
  
  
  if (is.null(dates)) {
    
    #if a subset of samples are identified for analysis, filter for those
    if (is.null(samps.to.inc)) {
      samp_data <- samp_data %>%
        dplyr::filter(AF >= min.alt.freq) #this applies if call_mutations was run with write.all.targets = TRUE - don't want to count things with zero reads.
    } else {
      samp_data <- samp_data %>%
        dplyr::filter(SAMP_NAME %in% samps.to.inc) %>%
        dplyr::filter(AF >= min.alt.freq)
    }
    
    all_summary <- data.frame()
    
    for (i in unique(samp_data$SAMP_NAME)) {
    
      #get rid of any mutation duplicates in the data, keeping one with highest AF
      #these generally occur when an amino acid change is caused by two or more SNPs - if so, it's repeated for each variant called
      samp_data_i <- samp_data %>% 
        dplyr::filter(SAMP_NAME == i) %>%
        dplyr::group_by(ALT_ID) %>%
        dplyr::arrange(desc(DP), .by_group = TRUE) %>%
        dplyr::ungroup() %>%
        dplyr::distinct(ALT_ID, .keep_all = TRUE)
      
      #join mutations observed in current sample in to lineage_muts df
      char_muts <- dplyr::left_join(x = lineage_muts, y = samp_data_i, by = "ALT_ID")
      
      #calculate depths
      #for all mutations
      dpth_all_i <- char_muts %>% 
        dplyr::pull(DP) %>% 
        mean(na.rm = TRUE)
      #for characteristic mutations
      dpth_characteristic_i <- char_muts %>% 
        dplyr::filter(characteristic == "Y") %>% 
        dplyr::pull(DP) %>%
        mean(na.rm = TRUE)
      
      
      if (use.median == FALSE) {
        #pull out the mutations that only occur in a single lineage to estimate relative proportions of each lineage identified as "present" in the sample based on chosen threshold.
        char_summary <- char_muts %>%
          dplyr::filter(characteristic == "Y") %>%
          dplyr::group_by(Lineage) %>%
          dplyr::summarize("Proportion_Present" = (sum(!is.na(SAMP_NAME)))/dplyr::n(),
                           "Mean_Freq" = mean(AF, na.rm = TRUE),
                           "Num_Target_Muts" = dplyr::n(),
                           "Sample" = i,
                           "Targets_Present" = ALT_ID[!is.na(SAMP_NAME)] %>% paste(collapse = ";"),
                           "Targets_Absent" = ALT_ID[is.na(SAMP_NAME)] %>% paste(collapse = ";"),
                           .groups = "drop") %>%
          dplyr::mutate_at(dplyr::vars(Mean_Freq), ~replace(., is.nan(.), 0))
      } else {
        #pull out the mutations that only occur in a single lineage to estimate relative proportions of each lineage identified as "present" in the sample based on chosen threshold.
        char_summary <- char_muts %>%
          dplyr::filter(characteristic == "Y") %>%
          dplyr::group_by(Lineage) %>%
          dplyr::summarize("Proportion_Present" = (sum(!is.na(SAMP_NAME)))/dplyr::n(),
                           "Mean_Freq" = median(AF, na.rm = TRUE),
                           "Num_Target_Muts" = dplyr::n(),
                           "Sample" = i,
                           "Targets_Present" = ALT_ID[!is.na(SAMP_NAME)] %>% paste(collapse = ";"),
                           "Targets_Absent" = ALT_ID[is.na(SAMP_NAME)] %>% paste(collapse = ";"),
                           .groups = "drop") %>%
          dplyr::mutate_at(dplyr::vars(Mean_Freq), ~replace(., is.nan(.), 0)) %>%
          dplyr::mutate_at(dplyr::vars(Mean_Freq), ~replace(., is.na(.), 0))
      }
      
      #add in depths
      if (depths.from == "characteristic") {
        char_summary$Mean_Depth <- dpth_characteristic_i
      } else {
        char_summary$Mean_Depth <- dpth_all_i
      }
      
      if(report.all == FALSE) {
        char_summary <- char_summary %>%
          dplyr::filter(Proportion_Present >= presence.thresh)
      }
      
      if (scale == TRUE) {
         freq_sum <- sum(char_summary$Mean_Freq)
         if (freq_sum > 1) {
           scaled_vals <- char_summary$Mean_Freq/freq_sum
           char_summary <- char_summary %>%
             dplyr::mutate("Mean_Freq" = scaled_vals)
         }
      }
      
      all_summary <- dplyr::bind_rows(all_summary, char_summary)
    }  
    all_summary <- all_summary %>% dplyr::select(Sample, Lineage, Num_Target_Muts, Proportion_Present, Mean_Freq, Mean_Depth, Targets_Present, Targets_Absent)
    
    if (use.median == TRUE) {
      all_summary <- all_summary %>% 
        dplyr::rename("Median_Freq" = "Mean_Freq")
    }
    
    if (!is.null(outfile.name)) {
      write.table(all_summary, 
                  file = outfile.name,
                  sep = ",", 
                  quote = FALSE,
                  row.names = FALSE,
                  col.names = TRUE)
    }

    return(all_summary)

    
  } else {  #have dates 
    dates_df <- readr::read_csv(dates, col_types = "cci")
    
    #merge in date info
    samp_data <- dplyr::left_join(x = samp_data, y = dates_df, by = "SAMP_NAME") %>%
      dplyr::mutate("date" = lubridate::mdy(DATE)) %>%
      dplyr::mutate("Location" = as.character(LOCATION)) %>%
      dplyr::select(-DATE, -LOCATION)
   
    #if a subset of locations are identified for analysis, filter for those
    if(!is.null(samps.to.inc)) {
      samp_data <- samp_data %>%
        dplyr::filter(SAMP_NAME %in% samps.to.inc)
    }
    
    if (is.null(locs.to.inc)) {
      samp_data <- samp_data %>%
        dplyr::filter(AF >= min.alt.freq) #this applies if call_mutations was run with write.all.targets = TRUE - don't want to count things with zero reads.
    } else {
      samp_data <- samp_data %>%
        dplyr::filter(Location %in% locs.to.inc) %>%
        dplyr::filter(AF >= min.alt.freq) #this applies if call_mutations was run with write.all.targets = TRUE - don't want to count things with zero reads.
    }
    
    #create master df that will store data for all selected lineages/variants
    all_summary <- data.frame()
    
    #loop over each unique sample
    for (i in unique(samp_data$SAMP_NAME)) {
      samp_data_i <- samp_data
      
      #If specific lineages are designated to target, filter for those
      if(!is.null(lineages.to.inc)) {
        lineage_muts <- lineage_muts %>%
          dplyr::filter(Lineage %in% lineages.to.inc)
      }

      samp_data_i <- samp_data_i %>% 
        dplyr::filter(SAMP_NAME == i) %>%
        dplyr::group_by(ALT_ID) %>%
        dplyr::arrange(desc(DP), .by_group = TRUE) %>%
        dplyr::ungroup() %>%
        dplyr::distinct(ALT_ID, .keep_all = TRUE)
      
      #join mutations observed in current sample in to lineage_muts df
      char_muts <- dplyr::left_join(x = lineage_muts, y = samp_data_i, by = "ALT_ID")
      
      #calculate depths
      #for all mutations
      dpth_all_i <- char_muts %>% 
        dplyr::pull(DP) %>% 
        mean(na.rm = TRUE)
      #for characteristic mutations
      dpth_characteristic_i <- char_muts %>% 
        dplyr::filter(characteristic == "Y") %>% 
        dplyr::pull(DP) %>%
        mean(na.rm = TRUE)
      
      if (use.median == FALSE) {
        #pull out the mutations that only occur in a single lineage to estimate relative proportions of each lineage identified as "present" in the sample based on chosen threshold.
        char_summary <- char_muts %>%
          dplyr::filter(characteristic == "Y") %>%
          dplyr::group_by(Lineage) %>%
          dplyr::summarize("Proportion_Present" = (sum(!is.na(SAMP_NAME)))/dplyr::n(),
                           "Mean_Freq" = mean(AF, na.rm = TRUE),
                           "Num_Target_Muts" = dplyr::n(),
                           "Targets_Present" = ALT_ID[!is.na(SAMP_NAME)] %>% paste(collapse = ";"),
                           "Targets_Absent" = ALT_ID[is.na(SAMP_NAME)] %>% paste(collapse = ";"),
                           .groups = "drop") %>%
          dplyr::mutate_at(dplyr::vars(Mean_Freq), ~replace(., is.nan(.), 0))
      } else {
        #pull out the mutations that only occur in a single lineage to estimate relative proportions of each lineage identified as "present" in the sample based on chosen threshold.
        char_summary <- char_muts %>%
          dplyr::filter(characteristic == "Y") %>%
          dplyr::group_by(Lineage) %>%
          dplyr::summarize("Proportion_Present" = (sum(!is.na(SAMP_NAME)))/dplyr::n(),
                           "Mean_Freq" = median(AF, na.rm = TRUE),
                           "Num_Target_Muts" = dplyr::n(),
                           "Targets_Present" = ALT_ID[!is.na(SAMP_NAME)] %>% paste(collapse = ";"),
                           "Targets_Absent" = ALT_ID[is.na(SAMP_NAME)] %>% paste(collapse = ";"),
                           .groups = "drop") %>%
          dplyr::mutate_at(dplyr::vars(Mean_Freq), ~replace(., is.nan(.), 0)) %>%
          dplyr::mutate_at(dplyr::vars(Mean_Freq), ~replace(., is.na(.), 0))
      }
      
      #add in depths
      if (depths.from == "characteristic") {
        char_summary$Mean_Depth <- dpth_characteristic_i
      } else {
        char_summary$Mean_Depth <- dpth_all_i
      }
      
      loc_i <- char_muts %>% dplyr::pull(Location) 
      loc_i <- loc_i[!is.na(loc_i)] %>% unique()
      date_i <- char_muts %>% dplyr::pull(date) 
      date_i <- date_i[!is.na(date_i)] %>% unique()
      
      char_summary <- char_summary %>%
        dplyr::mutate("Sample" = i,
                      "Location" = loc_i,
                      "Date" = date_i) 
      
      if(report.all == FALSE) {
        char_summary <- char_summary %>%
          dplyr::filter(Proportion_Present >= presence.thresh)
      }
      
      if (scale == TRUE) {
        freq_sum <- sum(char_summary$Mean_Freq)
        if (freq_sum > 1) {
          scaled_vals <- char_summary$Mean_Freq/freq_sum
          char_summary <- char_summary %>%
            dplyr::mutate("Mean_Freq" = scaled_vals)
        }
      }
      
      all_summary <- dplyr::bind_rows(all_summary, char_summary)
    } 
    
    all_summary <- all_summary %>% dplyr::select(Sample, Location, Date, Lineage, Num_Target_Muts, Proportion_Present, Mean_Depth, Targets_Present, Targets_Absent)
    
    if (use.median == TRUE) {
      all_summary <- all_summary %>% 
        dplyr::rename("Median_Freq" = "Mean_Freq")
    }
    
    if (!is.null(outfile.name)) {
      write.table(all_summary, 
                  file = outfile.name,
                  sep = ",", 
                  quote = FALSE,
                  row.names = FALSE,
                  col.names = TRUE)
    } 
    
    return(all_summary)
  }
}  

