module main;

import std.stdio;
import std.file : readText;
import std.string;
import std.csv;
import std.typecons;
import std.array;
import std.conv;
import std.functional;

void main(string[] args)
{
	SimData data = SimData();
	auto parsers = [&parseDrivers, &parseTravelers, &parseRoutes];
	foreach(p;parsers) p(data);

	data.setup();

	//data.step();
	//sdata.step();
	stdin.readln();
}

// Parses drivers
void parseDrivers(ref SimData simdata) {
	auto drivers = csvReader!Driver("data/drivers.csv".readText(),',');
	foreach(d; drivers) {
		simdata.drivers[d.startID] ~= d;
	}
}

// Parses travelers
void parseTravelers(ref SimData simdata) {
	auto travelers = csvReader!Traveler("data/passengers.csv".readText(),',');
	foreach(t; travelers) simdata.travelers ~= t;
}

// Parses Routes
void parseRoutes(ref SimData simdata) {
	auto files = ["47VanNess.csv","8xBayshore.csv", "49Mission.csv",
		"KIngleside.csv", "LTaraval.csv", "NJudah.csv","TThird.csv"];

	foreach(file; files) {
		Route *route = new Route();

		auto f = File("data\\" ~ file);
		route.name = f.readln(','); route.name.popBack();
		f.readln();
		foreach( r; f.byRecord!(string, int)("%s,%s") ) {
			auto s = new Station();
			s.id = r[1];
			s.name = r[0];
			simdata.stations[s.id] = s;
			route.stations ~= s;
		}
		simdata.routes ~= route;
	}
}

struct SimData {
	Routes routes = [];
	Driver[][int] drivers; // key by starting station ID
	Station*[int] stations;
	Traveler[] travelers;
	Vehicle*[] vehicles=[];
	// Set the vehicles at their stations as well as the travelers
	void setup() {
		// add vehicles and drives to routes
		foreach(r; routes) {
			auto v = makeVehicle(*r.origin(), *r);
			writeln(v.driver.name, " entering vehicle at origin station: ", r.origin().id, " ", v.currentStation().id);

			v = makeVehicle(*r.terminus(), *r);
			writeln(v.driver.name, " entering vehicle at terminus station: ", r.origin().id);
		}

		foreach(p; travelers) {
			stations[p.start].travelers ~= p;
		}
		/*
		foreach(k, v; stations) {
			writeln("Stop #", k, " has #", v.travelers.length);
		}
		*/
	}
	ref Vehicle makeVehicle(ref Station station, ref Route r) {
		if(drivers[station.id].length==0) {
			//TODO
		}
		auto v = new Vehicle(r);
		v.driver = drivers[station.id].front;
		drivers[station.id].popFront();
		vehicles ~= v;
		return *v;
	}

	void step() {
		//
		writeln("step started");
		foreach(v; vehicles) {
			updateStation(*v, *v.currentStation());
			v.travel(); // arriving on station
			writeln("Driver traveled:", v.driver.name, " ", v.last.id,"-",v.currentStation().id);
		}

		writeln("sten ended");
	}
	void updateStation(ref Vehicle v, ref Station s) {
		//writeln(s.travelers.length);
		foreach(t; s.travelers) {

			if( v.onTheWay( t.end ) ) v.board(t);
		}
	}
	void updatePerson(ref Traveler p, ref Station s) {

	}
}

struct Vehicle {
	Driver driver;
	Route route;
	Station*[] traveling; // list of stations in its current direction
	People passengers;
	bool goingToTerminus;
	int capacity = 50;
	Station* last;

	this(ref Route route) {
		this.route = route;
		traveling.length = route.stations.length;
		traveling[] = route.stations[];
		writeln(traveling.length);
	}

	void board(ref Traveler t) {
		if(isFull()) return;
		passengers ~= t;
		writeln(t.name, " is boarding on ", driver.name, "'s buss"); 
	}

	bool isFull() {
		return passengers.length >= 50;
	}

	bool onTheWay(int id) {
		bool r=false;
		foreach(t;traveling) if(t.id==id) return true;
		return false;
	}

	ref auto currentStation() { return traveling[0]; }

	ref auto travel() {
		last = currentStation();
		traveling = traveling[1..$];
		if(traveling.length==0) {
			traveling[] = route.stations[];
			goingToTerminus = !goingToTerminus;
			if(!goingToTerminus) traveling.reverse;
		}

		return currentStation();
	}
}
struct Traveler {
	string name;
	int start, end;
}
alias Routes = Route*[];
alias People = Traveler[];
struct Route {
	string name;
	Station*[] stations;
	auto origin() { return stations[0]; }
	auto terminus() { return stations[stations.length-1]; }
	bool atEndPoints(int id) {
		return origin().id == id || terminus().id == id;
	}
	bool has(int id) {
		bool r;
		foreach(s;stations) if(s.id==id) return true;
		return false;
	}
	alias stations this;
}
struct Station {
	string name;
	int id;
	People travelers;
	//Vehicle[] vehicles;
}
struct Driver {
	string name;
	int startID;
	int trips=0;
}