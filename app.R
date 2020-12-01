#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

## remotes::install_github("rforge/greenbrown/pkg/greenbrown/", force = TRUE)


# pkgload::load_all(path= "folder-with-pkg-code")

# using("shiny","ggplot2","sf","sp", "tidyverse", "raster", "qdapRegex", "lubridate", "doParallel", "foreach","parallel", "gsubfn","rgee", "reticulate", "rgdal", "magrittr", "kimisc")

# remotes::install_github("r-spatial/rgee", dependencies = TRUE)

# 
library(rsconnect)
# install.packages("slickR")
library(slickR)
library(shiny)
library(svglite)
# install.packages("shinybusy")
library(shinybusy)
library(greenbrown)
library(sf)
library(sp)
library(tidyverse)

library(raster)
library(qdapRegex)
library(lubridate)

library(doParallel)  #Foreach Parallel Adaptor 
library(foreach)
library(parallel)
library(gsubfn)
library(rgee)


# ee_install()
ee_Initialize(email = 'insert email')



##DO NOT RUN UNTIL YOU HAVE INTIALIZED GEE|  If you do, your system will brick because you need to define the python environment using rgee first.
library(reticulate)

library(rgdal)
library(DT)
library(magrittr)
library(kimisc)


years_s <- seq(ymd('1990-01-01'),ymd('2008-12-01'),by='year')
years_s_c <- as.character(years_s)
years_e <- seq(ymd('1990-01-01'),ymd('2008-12-01'),by='year')
# grep("2008-01-01",years_e)
years_e_c <- as.character(years_e)

years_e_c <- sort(years_e_c, decreasing = TRUE)


# y2 <- data.frame(Date=(seq(years_s[1], years_s[length(years_s)], by = 'year')))
# y2$Year <-year(y2$Date)
# years <- y2$Year



# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    titlePanel("Phenology Results Using EVI as the Main Band"),

    # Sidebar with a slider input for number of bins 
    # Sidebar with controls to select the variable to plot against year
    # also choose plotting and smooth colors, range of years, and smoothing width
    sidebarLayout(
    sidebarPanel(
        selectInput(inputId = "start", label ="Start Year:", choices = years_s_c, selected = years_s_c[17]),
        selectInput(inputId = "end", label = "End Year:", choices = years_e_c),
        selectInput(inputId = "Imagery_Collection", label = "Imagery Collection", choices = "LANDSAT/LT05/C01/T1_32DAY_EVI"),
        selectInput(inputId = "Band_Name",label = "EVI", choices = "EVI"),
        selectInput(inputId = "shapefile",label = "Default Ecoregion", choices = "Ecoregion_Small.shp")
    ),
    
    # Show a plot of the generated distribution
    mainPanel(
        tabsetPanel(id = 'dataset2',
                    tabPanel("Raster Brick", plotOutput("raster_brick")), 
                    tabPanel("Individual Plots", slickROutput("slickr", width = "50%", height = "100%")),
                    tabPanel("Trend Output", plotOutput("regression"))
        ),
        tabsetPanel(
            id = 'dataset',
            tabPanel("Dataframe Results", DT::dataTableOutput("mytable1"))
        )
    )
    )
)



# Define server logic required to draw a histogram
server <- function(input, output) {
    
    
    
    output$mytable1 <- DT::renderDataTable({
        
        
        # gee_extract <- function(){
            poly2 = matrix(c(-71.91549,42.43691, -71.91142 ,42.43696,  -71.91109, 42.43207, -71.91526, 42.43228, -71.91549, 42.43691),ncol = 2, byrow = TRUE)
            
            # poly3 <- st_polygon(list(poly2))
            
            
            poly2 <-  Polygon(poly2)
            
            Ps1 <-  SpatialPolygons(list(Polygons(list(poly2), ID = "a")), proj4string=CRS("+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"))
            poly2 <- as(Ps1, "sf")
            
            
            # 
            # 
            # shapefile <- Ps1
            # 
            # eco_mask2 <- st_read(shapefile,quiet = TRUE) %>% st_transform(4326) 
            # 
            # plot(eco_mask2)
            # 
            eco_mask_ee2 <- sf_as_ee(poly2)
            
            
            ##Bring in the imagery from RGEE
            # 
            s4 <- ee$ImageCollection(input$Imagery_Collection)
            # start <- '2000-01-01'
            # end <- '2008-01-01'
            # 
            
            # input <- reactive({years1 <- DF_phenmet_testarranged %>%
            #     filter (years >= input$start_date) %>%
            #     filter(years <= input$end_date)
            
            s4 <-  s4$filterDate(ee$Date(input$start),ee$Date(input$end))$filterBounds(eco_mask_ee2)
            
            # s4info1 <- s4$   getInfo()
            
            # band_name <- s4info1[["bands"]][[1]][["id"]]
            
            
            #Show the amount of images in the collection
            nbrImages_s4 = s4$size() %>% ee$Number()
            
            
            #Mapping the clip function over the collection
            s4 = s4$map(function(image){image$clip(eco_mask_ee2)})
            
            # s4info2 <- s4$getInfo()
            
            #Selecting the EVI band which holds the information
            s4 = s4$select(input$Band_Name)
            
            #Get information about the collection 
            # s4info3 <- s4$getInfo()
            
            
            
            
            ## SMALLER REGIONS
            
            #Get setup for the loop.  In case the loop crashes or doesn't work, you must rerun the above chunk first before running this chunk again. 
            
            np = import("numpy")      # Import Numpy 
            
            
            # nimages2 <- s4$size()$getInfo()  
            
            nimages2 <- s4 %>% ee$FeatureCollection$size() %>% ee$Number()
            ic_date2 <- ee_get_date_ic(s4)
            
            
            s4_img_list <- list()
            latlng2 <- list()
            lats2 <- list()
            lngs2 <- list()
            evi_values4 <- list()
            s4_names <- list()
            
            evi_values5 <- list()
            evi_values6 <- list()
            
            # nimages2$getInfo()
            
            
            for(i in seq(nimages2$getInfo())){
                # as.numeric(i)
                py_index <- i - 1
                s4_img <- ee$Image(s4 %>% ee$FeatureCollection$toList(1, py_index) %>% ee$List$get(0))
                s4_name <- s4_img %>% ee_get_date_img()
                s4_names[[i]] <- as.character(s4_name$time_start)
                s4_img <- s4_img$select(input$Band_Name)$rename(as.character(s4_name$time_start))
                s4_img_list[[i]] <- ee$Image$pixelLonLat()$addBands(s4_img)
                s4_img_list[[i]] <-  s4_img_list[[i]]$reduceRegion(reducer = ee$Reducer$toList(),
                                                                   geometry  = eco_mask_ee2,
                                                                   maxPixels = 1e6,
                                                                   scale = 30,
                                                                   bestEffort = TRUE)
            }
            
            func_dos <- function(q) {
                lats2 <- np$array((ee$Array(s4_img_list[[q]]$get("latitude")) %>% ee$Array$getInfo()))
                lngs2 <- np$array((ee$Array(s4_img_list[[q]]$get("longitude")) %>% ee$Array$getInfo()))
                
                
                evi_values4 <- list()
                
                for(index in  seq(nimages2$getInfo())) {
                    evi_values4[[index]] <-  ee$List(s4_img_list[[index]]$get(s4_names[[index]]))$getInfo()
                    
                }
                
                #Convert list elements of evi_values into num py arrays
                evi_values5 <- lapply(evi_values4,function(x){
                    np$array((x))
                })
                
                eviss4 <- evi_values5
                names(eviss4) <- ic_date2$id
                evis_df_s4 <- data.frame(x = lngs2,y = lats2,lapply(eviss4, "length<-", max(lengths(eviss4))))
            }
            s <- func_dos(1)
            
        
        
        
        ###################################
        evis_df_s4 <-  s
        # evis_df_s4 <- gee_extract()
        export(evis_df_s4)
        evisdf4 <- DT::datatable(evis_df_s4,extensions=c("Responsive",'Buttons'), options = list(dom = 'Bfrtip',
                                                                                                 buttons = c('copy', 'csv', 'excel', 'pdf', 'print')) 
        )
    })
    output$raster_brick <- renderPlot({
        pos <- grep(pattern = "NA", evis_df_s4)
        
            for(t in pos){
                if(t < ncol(evis_df_s4)){
                    evis_df_s4[t] <- (evis_df_s4[t+1]-evis_df_s4[t-1])/2
                }else
                    evis_df_s4[t] <- evis_df_s4[ncol(evis_df_s4)-1]
            }
            
        
        coords3 <- evis_df_s4 %>% dplyr::select(x, y) 
        
        evis_df_s4 <- evis_df_s4 %>% select(-c(x, y))
        
        evis_df_s4[evis_df_s4 < 0] = 0
        
        evis_df_s4_2 <- data.frame(coords3,evis_df_s4)
        
        #add reformatted dates
        
        colnames_df <-  names(evis_df_s4_2)
        
        #Extract dates from colummns
        dates <- gsubfn:::strapplyc(colnames_df, "[0-9]{8,}", simplify = TRUE)
        dates <- lubridate:::ymd(dates[-c(1:2)])
        
        names(evis_df_s4_2)[3:length(evis_df_s4_2)] <- as.character(dates)
        
        start_1 <- grep(input$start, colnames(evis_df_s4_2))
        end_1 <- grep(colnames(evis_df_s4_2[length(evis_df_s4_2)]), colnames(evis_df_s4_2))
        
        
        evis_df_s4_2 <- data.frame(coords3,evis_df_s4_2[start_1:end_1]) 
        
        
        
        evis_df_s4_2 <- evis_df_s4_2 %>%
            mutate_all(as.numeric)
        
        
        #Extract years from dates 
        y2 <- data.frame(Date=(seq(dates[1], dates[length(dates)], by = 'year')))
        y2$Year <-year(y2$Date)
        years <- y2$Year
        
        
        all_pixels_2 <- evis_df_s4_2 %>% dplyr:::select(-c(x, y)) %>% arrange() %>% slice(1:nrow(evis_df_s4_2)) %>% t() 
        
        
        # #create time series 
        EVIseries2 <- ts(all_pixels_2, start=c(years[1], 1), end=c(years[length(years)], 12), frequency=12)
        
        
        #Create empty lists for lapply
        Yt_interpolate_m3 <- list()
        Yt_interpolate_m4 <- list()
        Phen_2000_2007_3 <- list()
        
        
        #Apply Tspp # time series pre-processing ---interpolating across whole data set.  Use lapply to retain time series information. 
        ww <- ncol(EVIseries2)
        
        # system.time(
        # Yt_interpolate_m4 <- lapply(seq(ww), function(x){
        #   Yt_interpolate_m3[[x]]  <- TsPP(EVIseries2[,x], tsgf=TSGFspline)
        # }))
        
        # user  system elapsed 
        # 7.65    0.04    8.01 
        
        
        model.mse <- function(x){
            Yt_interpolate_m3[[x]]  <- greenbrown::TsPP(EVIseries2[,x], tsgf=TSGFspline)
        }
        
        
        
        
        model_phen <- function(x){
            Phen_2000_2007_3[[x]] <- greenbrown:::Phenology(Yt_interpolate_m4[[x]], approach="White")
        }
        
        UseCores <- detectCores() - 2
        
        
        clust <- makeCluster(UseCores)
        parallel:::clusterEvalQ(cl = clust, library("greenbrown"))
        parallel:::clusterExport(cl = clust, c("EVIseries2","Yt_interpolate_m3"), envir=environment())
        Yt_interpolate_m4 <- parLapply(clust, seq(ww), model.mse)
        
        # user  system elapsed 
        # 0.03    0.01    5.69 
        
        
        
        # clust <- makeCluster(UseCores)
        clusterEvalQ(clust, library("greenbrown"))
        clusterExport(clust, c('Phen_2000_2007_3', 'Yt_interpolate_m4'),envir=environment())
        rm(Phen_2000_2007_3)
        Phen_2000_2007_3 <- parLapply(clust, seq(ww), model_phen)
        kimisc:::export(Phen_2000_2007_3)
        #4 cores
        # #   user  system elapsed 
        # 0.24    0.07   39.80 
        
        #6 cores
        
        # user  system elapsed 
        # 0.22    0.03   31.72 
        
        
        stopCluster(clust)
        getDoParWorkers()
        registerDoSEQ()
        stopImplicitCluster()
        
        
        
        #Create empty list containers for loop
        sos2 <- list()
        eos2 <- list()
        los2 <- list()
        pop2 <- list()
        
        
        for(i in seq(ncol(EVIseries2))){
            sos2[[i]] <-  as.numeric( Phen_2000_2007_3[[i]][["sos"]])
            eos2[[i]] <-  as.numeric( Phen_2000_2007_3[[i]][["eos"]])
            los2[[i]] <-  as.numeric( Phen_2000_2007_3[[i]][["los"]])
            pop2[[i]] <-  as.numeric( Phen_2000_2007_3[[i]][["pop"]])
            
        }
        
        plot(Yt_interpolate_m4[[1]])
        
        sos2 <- unlist(sos2)
        eos2 <- unlist(eos2)
        los2 <- unlist(los2)
        pop2 <- unlist(pop2)
        
        
        coords3 <-evis_df_s4_2 %>% dplyr:::select(x, y) 
        
        repy <- length(years)
        coords4 <- coords3 %>% slice(rep(1:n(), each = repy))
        
        
        
        DF_phenmet_test2 <- data.frame(coords4,sos2, eos2, los2, pop2) %>% cbind(years)
        
        DF_phenmet_testarranged2 <- DF_phenmet_test2 %>% arrange(years)
        
        
        DF_phenmet_testarranged_sf2 = st_as_sf(DF_phenmet_testarranged2, coords = c("x", "y"), crs = 4326)
        
        
        year_chars2 <- as.character(years)
        #year_chars[1]
        
        separated_rasters2 <- list()
        # x <- length(years)
        
        for(g in seq(years)){
            separated_rasters2[[g]] <- lapply(years[g], function(x){DF_phenmet_testarranged2 %>% filter(years == year_chars2[g])})
        }
        
        DF_phenmet_testarranged2 %>% filter(years == year_chars2[1])
        
        
        rasterList2 <- brick()
        
        rasterList2 <- lapply(1:length(separated_rasters2), function(x){rasterFromXYZ(separated_rasters2[[x]][[1]])})
        
        # rasterList2 <- lapply(1:length(separated_rasters2), function(x){
        #     rasterFromXYZ(separated_rasters2[[x]][[1]]) 
        #     names(separated_rasters2[[x]][[1]]) <- paste(names(separated_rasters2[[x]][[1]]), year_chars2, sep = '_')
        # })
        # 
        
        rasterBrick2 <- brick(rasterList2)
        
        hh <- rep(year_chars2, 5)
        hh <- sort(hh)
        
        names(rasterBrick2) <- paste(names(rasterBrick2), hh, sep = '_')
        export(rasterBrick2)
        
        
        # library(gsubfn)
        # j <- strapplyc(names(rasterBrick_out), "\\.(\\d+)", simplify = TRUE)
        # 
        # hh <- rep(year_chars2, 5)
        # hh <- sort(hh)
        # 
        # 
        # for(i in seq(unique(j))){
        #     names(rasterBrick2) <- gsub(pattern = c(".",i), replacement = year_chars2[i], x= names(rasterBrick2))
        # }
        plot(rasterBrick2)
        # plots <- lapply(1:nlayers(rasterBrick2), function(i){
        #     xmlSVG({plot(rasterBrick2[[i]], main = names(rasterBrick2[[i]]))}, standalone=TRUE)
        # })
        # 
        # plotsAsSVG <- sapply(plots, function(sv){
        #     paste0("data:image/svg+xml;utf8,",as.character(sv))
        # })
        # plotsAsSVG <<- plotsAsSVG
        
        # plotsAsSVG
        # export(Phen_2000_2007_3)
        output$regression <- renderPlot({
            Phen_2000_2007_3 <- Phen_2000_2007_3
            plot(Phen_2000_2007_3[[1]])
        })
        output$slickr <- renderSlickR({
            # rm(plots)
            plots <- lapply(1:nlayers(rasterBrick2), function(i){
                xmlSVG({plot(rasterBrick2[[i]], main = names(rasterBrick2[[i]]))}, standalone=TRUE)
            })
            # rm(plotsAsSVG)
            plotsAsSVG <- sapply(plots, function(sv){
                paste0("data:image/svg+xml;utf8,",as.character(sv))
            })
            # rm(imgs)
            imgs <- plotsAsSVG
            slickR(imgs) + settings(initialSlide = 1) 
        })
        
        
        
    })
    # output$regression <- renderPlot({
    #     Phen_2000_2007_3 <- Phen_2000_2007_3
    #     plot(Phen_2000_2007_3[[1]])
    # })
    # output$slickr <- renderSlickR({
    #     rm(plots)
    #     plots <- lapply(1:nlayers(rasterBrick2), function(i){
    #         xmlSVG({plot(rasterBrick2[[i]], main = names(rasterBrick2[[i]]))}, standalone=TRUE)
    #     })
    #     rm(plotsAsSVG)
    #     plotsAsSVG <- sapply(plots, function(sv){
    #         paste0("data:image/svg+xml;utf8,",as.character(sv))
    #     })
    #     rm(imgs)
    #     imgs <- plotsAsSVG
    #     slickR(imgs)
    # })
}

# Run the application 
shinyApp(ui = ui, server = server)
