# Define what you want
Orgs <- c("ESCO", "KLPN")
Abx <- c("AMC", "AMX", "CIP", "GEN", "TRI")

save(Orgs, Abx, file ="output/data/params.Rdata")

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
