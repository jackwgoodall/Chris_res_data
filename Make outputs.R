# Define what you want

Orgs <- c("ESCO", "KLPN")
Exclude <- c("STAU", "STEP", "STCA")
Abx <- c("AMC", "AMX", "CIP", "GEN", "TRI")
Start <- as.Date("01/01/2022", format = "%d/%m/%Y") ## Enter this as dd/mm/YYYY
End <- as.Date("01/02/2022", format = "%d/%m/%Y") ## Enter this as dd/mm/YYYY


#### Nothing needs to be changed below here

save(Orgs, Exclude, Abx, Start, End, file ="output/data/params.Rdata")

html_output_name <- paste("Example Output", Sys.Date())
code_output_name <- "Example Output - R source code"

# Create output directories if they don't exist
if(!dir.exists("output/data")) {
  dir.create("output/data", recursive = TRUE)
}
if(!dir.exists("output/results")) {
  dir.create("output/results", recursive = TRUE)
}

# Make dataframe
source("scripts/format_data.R", local=new.env())

rmarkdown::render(input = "make_html.Rmd", 
                  output_file = glue::glue("{html_output_name}.html"),
                  output_dir = "output/results")
