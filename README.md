ass-its
=======

Super Ass-y Asset Tracker Thing

Background
----------
Needed some place to track some basic stuff about systems. We had Racktables for location, but not much else, and it was hard to get data out of unless you are a human. The machine to human ratio is currently around 250:1 and rapidly growing. But what did we want to track?

Asset => Something you want to track, typically a "big" item.

For any given asset, we want to track:

Name: Hostname if its a system, otherwise something descriptive and uniqe
Serial#: We can get this via facter for most things, but not everything, so we need a place to put it. 
PO#: We buy stuff. We need to remember the PO number for it all. 
Datacenter: Where the fuck is this stuff? 
Rack: ^^^ a bit more granular. 
RU's: The top and bottom most RU's taken by the system, which yeilds the size. 

Components => Anything we want to track, that is directly related to an asset (Storage shelves, gpu's, etc)

We want to track identical info for these. Most components will inherit much from the asset they belong to. But we need to be able to say that the diskshelf for a given system lives in another rack, or has a different PO. 


Why no Database? 
----------------

Because it would be silly. Really.

We have a list(array) of assets. Each asset is really a hash (key-value pair). Of of those keys might be "components", which would be a list (array) of other hashes (key-value). Thats it. This could be done in 1, or 2 tables. But why bother? 


Redis
------

I wanted to play with Redis. I also knew I could take me array of hashes (some nested), serialize to json in no time, and stuff this whole datastructure into a single Redis key. 

With the data in redis, suddenly all of our systems can be the place you query/edit the asset list. Systems can now update their serial number from what facter finds. They can update their location facts from the redis store. We can dump the whole list to a text file in any format we want in a second and take it offline for disaster recovery, or just safe keeping. 


What can it do $now
-------------------

* Import: Import assets (not components) from a csv, with a custom list/order of fields
* Export: Export Assets and components in YAML or JSON
* Search: Search assets by a given field
* Add/Modify/Delete assets
* Add/Modify/Delete/Search components


Todo
----

I'll be tracking things in the issues section, but there is the list of first pass items:

* Test! 
* Versioning/tracking changes
* make it better/less hacky. 
* facter integration
* puppet deployment of assit script. 
