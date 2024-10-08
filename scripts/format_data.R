#load defintions
load("output/data/params.Rdata")

# Load necessary libraries
pacman::p_load("tidyverse", "readxl", "lubridate")

# import dummy dataframe 
## including converting one to NA to show how this could be handled
## making a dummy 'location' column which will need the right syntax
df <- read_excel("input/Pseudo_res_data.xlsx")
df$Sensitivity[5] <- NA

### Format data frame
# Reshape - including only the abx in Abx and excluding gram pos
filtered_df <- df %>%
  arrange(desc(`Date Ordered`)) %>%
  filter(Antibiotic %in% c(Abx, "ESBL+", "AMPC+") & !(Organism %in% Exclude)) %>%
  pivot_wider(names_from = "Antibiotic",
              values_from = "Sensitivity") 


# Add some fake wards
filtered_df <- filtered_df %>%
  mutate(Location_Code = sample(c("W1", "W2", "W3", "W4", "W5"), size = n(), replace = TRUE))

# Remove the duplicates (**** SpecNo NEEDS TO BE CHANGED TO MRN - this is just an example)
df_unique <- filtered_df %>%
  distinct(Organism, SpecNo, Location_Code, .keep_all = TRUE)

# Make new Organism plus resistance mechanism
df_unique <- df_unique %>%
  mutate(Organism_BL = case_when(`ESBL+` == "P" ~ paste0(Organism, "_ESBL"),
                                 `AMPC+` == "P" ~ paste0(Organism, "_AMPC"),
                                  TRUE ~ Organism),
         SpecNo_org = paste(SpecNo, Organism, Location_Code, sep = "_"),  # this is what gets compared
         Org_location = paste(Organism_BL, Location_Code, sep = "_")) # this is what we can group on 

#paste0# Convert S/R to 1/0 (S and H made the same)
df_binary <- df_unique %>% mutate(across(all_of(Abx), ~ case_when(
  . == "S" | . == "H" ~ 0,
  . == "R" ~ 1,
  TRUE ~ as.numeric(.)
)))

# Find rows with NA values in any of the specified columns in the binary dataset
df_unique %>%
  filter(rowSums(is.na(select(df_binary, all_of(Abx)))) > 0) %>%
  saveRDS(file = "output/data/missing_rows.Rds")

# And one for use later
filtered_df_clean <- df_unique %>%
  filter(rowSums(is.na(select(df_binary, all_of(Abx)))) == 0)

# keep only those with complete data
df_binary <- df_binary %>%
  filter(rowSums(is.na(select(., all_of(Abx)))) == 0)

# Initialize an empty list to store the results
result_lists <- list()

# Loop through each organism separately
for (organism in unique(df_binary$Org_location)) {
  # Filter the binary dataframe by organism
  df_organism <- df_binary %>%
    filter(Org_location == organism)
  
  # Calculate the Manhattan distance matrix for the current organism
  distance_matrix <- as.matrix(dist(df_organism[, Abx], method = "manhattan"))
  
  colnames(distance_matrix) <- df_organism$SpecNo_org
  rownames(distance_matrix) <- df_organism$SpecNo_org
  
  # Loop through each row for the current organism
  for (i in 1:nrow(distance_matrix)) {
    # Find the column names where the distance is 0 or 1
    close_isolates <- colnames(distance_matrix)[which(distance_matrix[i, ] <= 1)]
    
    # Get the corresponding SpecNo_org value for this row
    spec_no_org <- rownames(distance_matrix)[i]
    
    # Store the result in the list using the SpecNo_org as the list name
    result_lists[[spec_no_org]] <- close_isolates
  }
}

# Remove identical results
unique_result_lists <- lapply(result_lists, function(x) sort(unique(x)))

# Function to filter SpecNo based on date range
filter_specno <- function(specno_vector, df) {
  # Filter the dataframe to include only rows where SpecNo matches those in the vector
  matched_df <- df %>% filter(SpecNo_org %in% specno_vector)
  
  if (nrow(matched_df) == 0) return(character(0))
  
  # Find the most recent date in the filtered dataframe
  max_date <- max(matched_df$`Date Ordered`, na.rm = TRUE)
  
  # Calculate the threshold date (14 days before the most recent date)
  threshold_date <- max_date - 14
  
  # Filter the SpecNo vector to include only those within the 14-day window
  filtered_specno <- matched_df %>%
    filter(`Date Ordered` >= threshold_date) %>%
    pull(SpecNo_org)
  
  # Return only those SpecNo that were originally in the specno_vector
  return(filtered_specno[filtered_specno %in% specno_vector])
}

# Apply the function to each vector in the list
filtered_df_clean$`Date Ordered` <- as.Date.POSIXct(filtered_df_clean$`Date Ordered`)
filtered_list <- lapply(result_lists, filter_specno, df = filtered_df_clean)

# Remove solo results again
filtered_list_solo <- filtered_list[sapply(filtered_list, length) > 1]

# Remove any empty lists that might result from the filtering
filtered_list_solo_clean <- filtered_list_solo[sapply(filtered_list_solo, length) > 0]

#Remove the duplicated clusters
# Step 1: Sort each cluster and keep names
sorted_list <- lapply(filtered_list_solo_clean, sort)

# Step 2: Create a named list to keep track of unique clusters
unique_clusters <- list()

# Step 3: Loop through the sorted list and add only unique clusters to unique_clusters
for (name in names(sorted_list)) {
  cluster <- sorted_list[[name]]
  
  # Check if the cluster is already in unique_clusters
  if (!any(sapply(unique_clusters, function(x) identical(x, cluster)))) {
    unique_clusters[[name]] <- cluster
  }
}

save(unique_clusters, file = "output/data/unique_clusters.Rdata")
save(filtered_df_clean, file = "output/data/filtered_df_clean.Rdata")
