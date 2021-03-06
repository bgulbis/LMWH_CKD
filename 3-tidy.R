# tidy.R
# 
# organize data for analysis

source("0-library.R")

# raw data ----

raw.blood <- read_edw_data(data.dir, file.name = "blood")
raw.demograph <- read_edw_data(data.dir, file.name = "demographics")
raw.diagnosis <- read_edw_data(data.dir, file.name = "diagnosis")
raw.home.meds <- read_edw_data(data.dir, file.name = "home_meds")
raw.labs <- read_edw_data(data.dir, file.name = "labs")
raw.measures <- read_edw_data(data.dir, file.name = "measures")
raw.meds.cont <- read_edw_data(data.dir, file.name = "meds_continuous", check.distinct = FALSE)
raw.meds.sched <- read_edw_data(data.dir, file.name = "meds_sched")
raw.procedures <- read_edw_data(data.dir, file.name = "procedures")
raw.radiology <- read_edw_data(data.dir, file.name = "radiology")
raw.surgeries <- read_edw_data(data.dir, file.name = "surgeries")
raw.enox.freq <- read_edw_data(data.dir, file.name = "meds_sched_enox", type = "meds_sched_freq")
raw.probs <- read_edw_data(data.dir, file.name = "problems")

if (!exists("data.patients")) {
    data.patients <- readRDS("included_patients.Rds")
}

incl.pts <- data.patients$pie.id

# demographics ----
data.demograph <- raw.demograph %>%
    inner_join(select(data.patients, pie.id, afib:vte), by = "pie.id")

rm(data.patients)

saveRDS(data.demograph, "Preliminary Analysis/demograph.Rds")

data.groups <- select(data.demograph, pie.id, group)

# diagnosis ----
# get desired diagnosis codes
ref.pmh.codes <- read_data(lookup.dir, "pmh_lookup.csv")
# use standard tidying function
data.diagnosis <- tidy_data(raw.diagnosis, "diagnosis", ref.data = ref.pmh.codes, 
                            patients = data.groups) 

saveRDS(data.diagnosis, "Preliminary Analysis/diagnosis.Rds")

# home meds ----
# get desired medication classes
ref.home.meds <- read_data(lookup.dir, "home_meds_lookup.csv")
# use standard tidying function
data.home.meds <- tidy_data(raw.home.meds, "meds_outpt", ref.data = ref.home.meds, 
                            patients = data.groups)

# hospital meds ----

# get all enoxaparin courses and filter to only included patients
if (!exists("tmp.enox.courses")) {
    tmp.enox.courses <- readRDS("enoxaparin_courses.Rds")
}

data.enox.courses <- filter(tmp.enox.courses, pie.id %in% incl.pts) %>%
    select(-last.datetime, -course.count) %>%
    mutate(freq = factor(freq, exclude = "")) 

# get continuous medications
ref.meds.confound <- read_data(lookup.dir, "meds_confound")
# use standard tidying function
tmp.meds.cont <- tidy_data(raw.meds.cont, "meds_cont", 
                           ref.data = ref.meds.confound, 
                           sched.data = raw.meds.sched)
# get running times
tmp.meds.cont <- calc_runtime(tmp.meds.cont)
# summarize data
data.meds.cont <- summarize_cont_meds(tmp.meds.cont)

# use standard tidying function for scheduled medications
tmp.meds.sched <- tidy_data(raw.meds.sched, "meds_sched", 
                            ref.data = ref.meds.confound)

# diagnostic scans ----
# get list of FINs for manual lookup
ref.fins <- read_edw_data(data.dir, "identifiers", type = "id") 
    
man.review <- raw.radiology %>%
    inner_join(data.enox.courses, by = "pie.id") %>%
    inner_join(ref.fins, by = "pie.id") %>%
    filter(rad.datetime >= first.datetime,
           str_detect(rad.type, "CT|Doppler|MRI|US"))  %>%
    select(fin, rad.datetime, rad.type)

# export to csv file
write_csv(man.review, "diagnostic_scans.csv")

# problem list ----

