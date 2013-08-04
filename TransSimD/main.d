module main;

import std.stdio;
import std.file : readText;
import std.string;
import std.csv;
import std.typecons;
import std.array;
import std.conv;
import std.functional;

enum SIM_STEPS = 60;

void main(string[] args)
{
	writeln("sim started");
	SimData data = SimData();
	auto parsers = [&parseDrivers, &parseTravelers, &parseRoutes, &parseTransfers];
	foreach(ref p;parsers) p(data);
	writeln("parsed. Travelers: ", data.starting.length, " Routes: ", data.routes.length, " Drivers: ", data.drivers.length);
	data.setup();

	writeln("setup finished");

	for(int i=0; i < SIM_STEPS; i++) data.step();

	stdin.readln();
}

// Parses drivers
void parseDrivers(ref SimData simdata) {
	auto drivers = csvReader!Driver("data/drivers.csv".readText(),',');
	foreach(ref d; drivers) {
		simdata.drivers[d.startID] ~= d;
	}
}

// Parses travelers
void parseTravelers(ref SimData simdata) {
	auto f = File("data/passengers.csv");
	foreach(ref r; f.byRecord!(string, int, int)("%s,%s,%s") ) {
		Traveler* t = new Traveler();
		t.name = r[0]; t.start = r[1]; t.end = r[2];
		//simdata.travelers[t.key()] = t;
		simdata.starting.add(t);
	}
}

void parseTransfers(ref SimData simdata) {
	auto f = File("data\\TransferStops.csv");
	f.readln();
	foreach(ref r; f.byRecord!(int, int, string, string)("%s,%s,%s,%s") ) {
		Transfer t = Transfer();
		t.p1 = r[0];
		t.p2 = r[1];
		t.description = std.string.strip(r[2]);
		t.routes = std.string.strip(r[3]);

		Route route = Route();
		route.name="rail";
		route.stations ~= simdata.stations[t.p1];
		route.stations ~= simdata.stations[t.p2];
	}
}

// Parses Routes
void parseRoutes(ref SimData simdata) {
	auto files = ["47VanNess.csv","8xBayshore.csv", "49Mission.csv",
		"KIngleside.csv", "LTaraval.csv", "NJudah.csv","TThird.csv"];

	foreach(ref file; files) {
		Route route = Route();

		auto f = File("data\\" ~ file);
		route.name = f.readln(','); route.name.popBack();
		f.readln();
		foreach(ref r; f.byRecord!(string, int)("%s,%s") ) {
			auto s = Station();
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
	Station[int] stations;
	Travelers starting;
	Travelers finished;
	Vehicle[] vehicles=[];
	// Set the vehicles at their stations as well as the travelers
	void setup() {
		// add vehicles and drives to routes
		foreach(ref r; routes) {
			auto v = makeVehicle(r.origin(), r);
			writeln(v.driver.name, " entering vehicle at origin station: ", r.origin().id, " = ", v.currentStation().id);

			v = makeVehicle(r.terminus(), r);
			v.reverse();
			writeln(v.driver.name, " entering vehicle at terminus station: ", r.terminus().id, " = ", v.currentStation().id);
		}

		auto p=starting.first;
		while(p!=null) {
			writeln(p.start);
			auto s = stations[p.start];
			writeln("s",s);
			auto t = s.travelers;
			writeln("t ", t);
			p = starting.sendTo( p,t );
			writeln("p ",p);
		}
		writeln("setup end");
	}

	Vehicle makeVehicle(in Station station, ref Route r) {
		auto v = Vehicle(r);
		if(r.name=="rail") {
			// No driver for rail car
		} else {
			v.driver = getDriver(station.id);
		}
		vehicles ~= v;
		return v;
	}

	Driver getDriver(in int stationID){
		auto d = drivers[stationID].front;
		drivers[stationID].popFront();
		return d;
	}

	void step() {
		//
		writeln("step started");
		foreach(ref v; vehicles) {
			auto t = v.passengers.first;
			while(t!=null) {
				if(t.end==v.currentStation().id) {
					//travelerExits(&t, v);
					writeln("Traveler ",t.name, " exits vehicle: ", v.driver.name, " from route: ", v.route.name);
					t = v.passengers.sendTo(t, finished);
				}
				else t = t.next;
			}
			if(v.driver.trips > 6) {
				writeln("time for driver change");
				v.driver = getDriver(v.currentStation().id);
			}
			v.call();
			v.travel(); // arriving on station
			//writeln("Driver traveled:", v.driver.name, " ", v.last.id,"->",v.currentStation().id);
		}

		writeln("step ended");
	}


	void travelerExits(ref Traveler t, ref Vehicle v) {
		//v.travelers.remove(v);
		//TODO //v.passengers.remove(t.key());

	}

	void updatePerson(ref Traveler p, ref Station s) {

	}
}

struct Vehicle {
	Driver driver;
	Route route;
	// TODO: use the route copy for position tracking
	Station[] traveling; // list of stations in its current direction
	Travelers passengers;

	bool goingToOrigin;
	int capacity = 50;
	//int passengers = 0;
	Station last;

	this(ref Route route) {
		this.route = route;
		traveling.length = route.stations.length;
		traveling[] = route.stations[];
	}

	void call() {
		Station s = currentStation();
		//writeln(s.travelers.length);
		//Traveler[] boardedTravelers;
		//foreach(ref t; s.travelers) {
		auto t = s.travelers.first;
		while(t!=null) {
			if( isFull() ) continue;
			if( onTheWay( t.end ) ) {
				t = s.travelers.sendTo(t, passengers);
			}
			else t = t.next;
		}
		//foreach(ref t; boardedTravelers) s.travelers.remove(t.key());
	}

	bool canBoard() {
		return !isFull();
	}
	/*
	void board(ref Traveler t) {
		if(isFull()) return;
		passengers ~= t;
		//t.vehicle = this;
		//if(isFull()) return;
		//passengers[t.key()] = &t;
		///writeln(t.name, " is boarding on ", driver.name, "'s buss"); 
	}*/

	bool isFull() {
		return passengers.length >= 50;
	}

	bool onTheWay(int id) {
		bool r=false;
		foreach(ref t;traveling) if(t.id==id) return true;
		return false;
	}

	void reverse() {
		goingToOrigin = !goingToOrigin;
		if(goingToOrigin) traveling = traveling.reverse;
	}

	ref auto currentStation() { return traveling[0]; }

	ref auto travel() {
		last = currentStation();
		traveling.popFront();
		//writeln(traveling.length);
		if(traveling.length==0) {
			traveling.length = route.stations.length;
			traveling[] = route.stations[];
			//writeln("::",traveling.length);
			reverse();
			if(route.name!="rail") driver.trips++; // Update driver
		}

		return currentStation();
	}
}
struct Traveler {
	mixin DNode!Traveler;
	string name;
	int start, end;

	private string _key=null;
	ref string key() {
		if(_key==null) _key = name ~ std.conv.to!string(start) ~ ":" ~ std.conv.to!string(end);
		return _key;
	}
}
struct Transfer {
	int p1;
	int p2;
	string description;
	string routes;
}

alias Routes = Route[];
//alias People = Traveler[string];
struct Route {
	string name;
	Station[] stations;
	ref auto origin() { return stations[0]; }
	ref auto terminus() { return stations[stations.length-1]; }
	bool atEndPoints(int id) {
		return origin().id == id || terminus().id == id;
	}
	bool has(int id) {
		bool r;
		foreach(ref s;stations) if(s.id==id) return true;
		return false;
	}
	alias stations this;
}
struct Station {
	string name;
	int id;
	//People travelers;
	//mixin LinkedList!Traveler people;
	//Vehicle[] vehicles;
	Travelers travelers;
	///TODO Vehicle vehicles;

}
struct Driver {
	string name;
	int startID;
	int trips=0;
}
alias LinkedList!Traveler Travelers;
struct LinkedList(T) {
	mixin LinkedListM!T;
	// Returns the next items in the old list
	T* sendTo(T* node, ref LinkedList!T list) {
		writeln("a1");
		T* next = node.next;
		writeln("a2");
		remove(node);
		writeln("a3");
		list.add(node);
		writeln("a4");
		return next;
	}
}
mixin template LinkedListM(T) {
	private int _length=0;
	private T* head;
	@property {
		public int length() {
			return _length;
		}
		public T* first() {
			return head;
		}
	}

	ref T add(T* node) {
		assert(node != null);
		assert(node != head);

		if(head!=null){
			node.next = head;
			head.prev = node;
		}
		_length++;
		head = node;
		return *node;
	}
	void remove(T* node) {
		writeln("b1");
		if(node==head) {
			head = node.next;
			delete head;
		}
		writeln("b2");
		if(node.prev!=null) {
			writeln(node, " ", node.prev);
			if(node.next!=null) node.prev.next = node.next; 
			delete node.prev;
		}
		writeln("b3");
		if(node.next!=null) {node.next.prev = node.prev; delete node.next;}
	}
	//mixin LinkedListM!T list;
	//alias list this;
}
mixin template DNode(T) {
	T* prev;
	T* next;
}