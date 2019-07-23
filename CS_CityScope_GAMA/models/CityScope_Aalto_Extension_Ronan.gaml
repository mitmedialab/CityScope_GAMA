/***
* Name: CityScope_ABM_Aalto
* Author: Ronan Doorley and Arnaud Grignard
* Description: This is an extension of the orginal CityScope Main model.
* Tags: Tag1, Tag2, TagN
***/

model CityScope_ABM_Aalto

import "CityScope_main.gaml"

global{
	//GIS folder of the CITY	
	string cityGISFolder <- "./../includes/City/otaniemi";	
	
	// Variables used to initialize the table's grid position.
	float angle <- -9.74;
	point center <- {1600, 1000};
	float brickSize <- 24.0;
	float cityIOVersion<-2.1;
	
	//	city_io
	string CITY_IO_URL <- "https://cityio.media.mit.edu/api/table/cs_aalto_2";
	// Offline backup data to use when server data unavailable.
	string BACKUP_DATA <- "../includes/City/otaniemi/cityIO_Aalto.json";
	
    //Sliders that dont exisit in Aalto table and are only used in version 1.0 
	int	toggle1 <- 2;
	int	slider1 <-2;
	// TODO: Hard-coding density because the Aalto table doesnt have it.
	list<float> density_array<-[1.0,1.0,1.0,1.0,1.0,1.0];
	
	// TODO: mapping needs to be fixed for Aalto inputs
	map<int, list> citymatrix_map_settings <- [-1::["Green", "Green"], 0::["R", "L"], 1::["R", "M"], 2::["R", "S"], 3::["O", "L"], 4::["O", "M"], 5::["O", "S"], 6::["A", "Road"], 7::["A", "Plaza"], 
		8::["Pa", "Park"], 9::["P", "Parking"], 20::["Green", "Green"], 21::["Green", "Green"]
	]; 
	

	// Babak dev:
	int max_walking_distance <- 2000 	min:0 max:3000	parameter: "maximum walking distance form parking:" category: "people settings";
	int number_of_people <- 1 min:0 max: 2000 parameter:"number of people in the simulation" category: "people settings";
	int min_work_start <- 4;
	int max_work_start <- 10;
	int min_work_end <- 17;
	int max_work_end <- 18;
	
	graph car_road_graph;
	graph pedestrian_road_graph;
	
	file parking_footprint_shapefile <- file(cityGISFolder + "/parking_footprint.shp");
	file roads_shapefile <- file(cityGISFolder + "/car_network.shp");
	file pedestrian_road_shapefile <- file(cityGISFolder + "/pedestrian_network.shp");
	
	int current_hour update: (time / #hour) mod 24;
	
	geometry shape <- envelope(bound_shapefile);
	
	
	init {
		create parking from: parking_footprint_shapefile with: [capacity::int(read("capacity")), excess_time::int(read("time"))];
		create Aalto_buildings from: buildings_shapefile with: [usage::string(read("Usage")), scale::string(read("Scale"))]{
			if usage = "O"{
				color <- #orange;
			}
		}
		create car_road from: roads_shapefile;
		car_road_graph <- as_edge_graph(car_road);
		
		create pedestrian_road from: pedestrian_road_shapefile;
		pedestrian_road_graph <- as_edge_graph(pedestrian_road);
		
		create aalto_people number: number_of_people{
			working_place <- one_of(Aalto_buildings where (each.usage = "O" ));
			living_place <- one_of(Aalto_buildings where (each.usage = "R" ));
			location <- any_location_in(living_place);
			time_to_work <- min_work_start + rnd(max_work_start - min_work_start);
			time_to_sleep <- min_work_end + rnd(max_work_end - min_work_end);
			objective <- "resting";
			}
		
		
		
	}
	
}

species Aalto_buildings schedules:[] {
	string usage;
	string scale;
	rgb color <- #gray;
	aspect base {
		draw shape color: color;
	}
}


species parking schedules:[] {
	int capacity;
	int excess_time;
	
	aspect base {
		draw shape color: #lightgray ;
	}
	
}

species aalto_people skills: [moving] {
	rgb color <- #red ;
	bool driving_car <- true;
	Aalto_buildings living_place;
	Aalto_buildings working_place;
	
	int time_to_work;
	int time_to_sleep;
	
	
//	list<parking> list_of_available_parking <- parking where (distance_to(each.location, working_place) < max_walking_distance  );
	bool mode_of_transportation_is_car <- true;
	point the_target_parking;
	
	string objective;
	point the_target <- nil;
	
	// ----- REFLEXES 


	
	
	reflex time_to_go_to_work when: current_hour = time_to_work and objective = "resting" {
		
		objective <- "working";
		if (mode_of_transportation_is_car = true) {
			the_target_parking <- any_location_in(one_of(parking where (each.capacity > 0)));
			the_target <- any_location_in(working_place);
		}	
		
		else {
			the_target <- any_location_in(working_place);
		}
	}
	
	
	
//	reflex time_to_go_home when: current_hour = time_to_sleep and location = point(working_place) and objective = "working" {
	reflex time_to_go_home when: current_hour = time_to_sleep and objective = "working" {
		objective <- "resting";
		the_target <- any_location_in(living_place);
	}
	
	reflex change_mode_of_transportation when: location = the_target_parking {
		if (driving_car = true){
			driving_car <- false;
			
		}
		else {
			driving_car <- true;
		}
	}

	reflex move when: the_target != nil {
		if (driving_car = true){
			if (objective = "working"){
				do goto target: the_target_parking on: car_road_graph speed: (8.0 + rnd(0,5));
			}
			else{
				do goto target: the_target on: car_road_graph speed: (2.0 + rnd(0,5));
			}
		}
		else {
			if (objective = "working"){
				do goto target: the_target on: pedestrian_road_graph speed: (8.0 + rnd(0,5));
			}
			else {
				do goto target: the_target_parking on: pedestrian_road_graph speed: (2.0 + rnd(0,5));
			}
		}
		
      	if the_target = location {
        	the_target <- nil ;
		}
	}
	
	aspect base {
		draw circle(50) color:#red;
	}
}



// ----------------- ROADS SPECIES ---------------------

species car_road {
	aspect base{
		draw shape color: #lightblue width:2;
	}
}

species pedestrian_road {
	aspect base{
		draw shape color: #lightgreen;
	}
}


// ----------------- EXPREIMENTS -----------------
experiment test type: gui {
	output {
		display test type: opengl  {
			species car_road aspect: base ;
			species pedestrian_road aspect: base ;
			species parking aspect: base ;
			species Aalto_buildings aspect:base;
			species aalto_people aspect:base;

			}
			
		}

}