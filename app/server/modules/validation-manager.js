/**
 * Created by megam on 26/06/2016.
 */

var MongoDB 	= require('mongodb').Db;
var Server 		= require('mongodb').Server;
var config = require('../config');
var json2csv = require('json2csv');

/*
 ESTABLISH DATABASE CONNECTION
 */

var dbName = process.env.DB_NAME || 'gearsketch';
var dbHost = process.env.DB_HOST || 'localhost'
var dbPort = process.env.DB_PORT || 27017;

var db = new MongoDB(dbName, new Server(dbHost, dbPort, {auto_reconnect: true}), {w: 1});
db.open(function(e, d){
    if (e) {
        console.log(e);
    } else {
        if (process.env.NODE_ENV == 'live') {
            db.authenticate(process.env.DB_USER, process.env.DB_PASS, function(e, res) {
                if (e) {
                    console.log('mongo :: error: not authenticated', e);
                }
                else {
                    console.log('mongo :: authenticated and connected to database :: "'+dbName+'"');
                }
            });
        }	else{
            console.log('mongo :: connected to database :: "'+dbName+'"');
        }
    }
});

var validationResults = db.collection('validationresults');

/* record insertion, update & deletion methods */

// "ewerwer":{
//     user:"ewerwer",
//         level:1,
//         wrong_validations:4,
//         completed:true,
//         times:[20,55,66,84],
//         completed_time: 77
//  }

exports.addNewResult = function(user,newData, callback)
{
    if(user)
        validationResults.findOne({user:user}, function(e, o){
            var record=o;
            if(!o) {
                record={};
                record.levels={};
                record.user=user;
            }
            var level=record.levels[newData.key];
            if(!level){
                level={}
                level.level=newData.level;
                level.key=newData.key;
                level.times=[];
                level.wrong_validations=0;
            }
            if(newData.completed){
                level.completed=true;
                level.completed_time=newData.time;
            }else{
                level.wrong_validations++;
                level.times.push(newData.time);
            }
            record.levels[newData.key]=level;
            if(o){
                validationResults.save(record, {safe: true}, function(e) {
                    if (e) callback(e);
                    else callback(null, o);
                });
            }else{
                validationResults.insert(record, {safe: true}, callback);
            }
        });
}

exports.unlockCode = function(user,code , callback)
{
    if(user && config.unlockCode === code){
        validationResults.findOne({user:user}, function(e, o){
            var record=o;
            if(!o) {
                record={};
                record.levels={};
                record.user=user;
            }
            record.showAllLevels=true;
            if(o){
                validationResults.save(record, {safe: true}, function(e) {
                    // if (e) callback(e);
                    // else callback(null, o);
                });
            }else{
                validationResults.insert(record, {safe: true}, callback);
            }
        });
    }
}

exports.getUserResults = function(user, callback)
{
    validationResults.findOne({user:user}, function(e, o){  callback(o); });
}


exports.generateStatistics = function (callback)
{
    validationResults.find().toArray(function(err,results) {
        var data = [];
        for(var i=0;i<results.length;i++) {
            var result = results[i]
            for (var property in result.levels) {
                var reg = {};
                reg.user = result.user;
                if (result.levels.hasOwnProperty(property)) {
                    var current=result.levels[property]
                    reg.level = current.level;
                    reg.key = current.key;
                    reg.wrongTries = current.times.length;
                    reg.completed = current.completed? true:false;
                    var sum = 0;
                    for( var p = 0; p < current.times.length; p++ ){
                        sum += parseFloat( current.times[p]);
                    }

                    reg.wrongAvgTIme = sum!==0?sum/current.times.length:0;
                    reg.timeCompleted = current.completed_time?current.completed_time:0;
                }

                data.push(reg);
            }
        }
        callback(data);
    });
}

exports.generateReport = function(callback)
{
    this.generateStatistics(function(data) {
        var fields = ['user', 'level','completed','timeCompleted','wrongTries','wrongAvgTIme'];
        var fieldNames = ['Usuario','Nivel','Completado','Tiempo para completarlo','Intentos fallidos','Promedio de tiempo de intentos fallidos']
        var csv = json2csv({data: data, fields: fields, fieldNames: fieldNames});
        callback(csv);
    });
}

var getObjectId = function(id)
{
    return new require('mongodb').ObjectID(id);
}
