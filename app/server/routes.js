
var CT = require('./modules/country-list');
var AM = require('./modules/account-manager');
var EM = require('./modules/email-dispatcher');
var VM = require('./modules/validation-manager');
var path = require("path");
var config = require('./config')


module.exports = function(app) {

// main login page //
	app.get('/', function(req, res){
	// check if the user's credentials are saved in a cookie //
		if( req.session.user != undefined ) {
			res.redirect('/menu');
		}
		else if (req.cookies.user == undefined || req.cookies.pass == undefined){
			res.render('login', { title: 'Hello - Please Login To Your Account' });
		}	else{
	// attempt automatic login //
			AM.autoLogin(req.cookies.user, req.cookies.pass, function(o){
				if (o != null){
				    req.session.user = o;
					res.redirect('/menu');
				}	else{
					res.render('login', { title: 'Hello - Please Login To Your Account' });
				}
			});
		}
	});
	
	app.post('/', function(req, res){
		AM.manualLogin(req.body['user'], req.body['pass'], function(e, o){
			if (!o){
				res.status(400).send(e);
			}	else{
				req.session.user = o;
				if (req.body['remember-me'] == 'true'){
					res.cookie('user', o.user, { maxAge: 900000 });
					res.cookie('pass', o.pass, { maxAge: 900000 });
				}
				res.status(200).send(o);
			}
		});
	});

// levels-menu  //
    app.get('/menu', function(req, res) {
        if (req.session.user == null) {
            // if user is not logged-in redirect back to login page //
            res.redirect('/');
        } else {
            VM.getUserResults(req.session.user.user, function (o) {
                if (o) {
                    //console.log("encontre "+ Object.keys(o.levels));
                    var lvls=Object.keys(o.levels);
                    var usrLevels = o.showAllLevels? config.levels :lvls.filter(function(x){return o.levels[x].completed })
                    res.render('levels-menu', {
                        udata: req.session.user,
                        levels: config.levels,
                        unlocked: usrLevels,
                        done: usrLevels.length,
                        locked: config.levels.filter(function(x) { return usrLevels.indexOf(x) < 0 }),
						openLevelImages: config.openLevelImages,
						doneLevelImages: config.doneLevelImages,
						lockedLevelImages: config.lockedLevelImages
                    });
                } else {
                    res.render('levels-menu', {
                        udata: req.session.user,
                        levels: config.levels,
                        unlocked: {},
                        done: 0,
                        locked: config.levels,
						openLevelImages: config.openLevelImages,
						doneLevelImages: config.doneLevelImages,
						lockedLevelImages: config.lockedLevelImages
                    });
                }

                //res.sendFile(path.join(__dirname+'/html/index.html'));

                // res.render('home', {
                // 	title : 'Control Panel',
                // 	countries : CT,
                // 	udata : req.session.user
                // });
            });
        }
    });
// stats  //
	app.get('/'+config.statsURL, function(req, res) {
		if (req.session.user == null) {
			// if user is not logged-in redirect back to login page //
			res.redirect('/');
		} else {
			VM.generateStatistics(function (o) {
				res.render('stats', {
					data: o,
				});
			});
		}
	});


	app.get('/'+config.unlockCode, function(req, res){
		if (req.session.user == null){
			res.redirect('/');
		}	else{
			// Estoy dejando esto asi, para que pueda desbloquearse desde un modal de ser necesario con pocas modificaciones
            // si se quiere hacer el modal, sacar config.unlockCode, y cambiar por info en el req
			VM.unlockCode(req.session.user.user, config.unlockCode)
			res.redirect('/');
			// req.body['name']
			// req.session.user._id,
		}
	});


// boards //

    app.get('/board', function(req, res) {
        if (req.session.user == null){
            // if user is not logged-in redirect back to login page //
            res.redirect('/');
        }	else{
            res.sendFile(path.join(__dirname+'/html/index.html'));
        }
    });


// boards //

	app.get('/csv', function(req, res) {
		if (req.session.user == null){
			// if user is not logged-in redirect back to login page //
			res.redirect('/');
		}	else{
            VM.generateReport(function(csv){
                res.setHeader('Content-disposition', 'attachment; filename=results.csv');
                res.setHeader('Content-type', 'text/plain');
                res.charset = 'UTF-8';
                res.write(csv);
                res.end();
            });
		}
	});


// logged-in user homepage //

	app.get('/home', function(req, res) {
		if (req.session.user == null){
	// if user is not logged-in redirect back to login page //
			res.redirect('/');
		}	else{
			// res.sendFile(path.join(__dirname+'/html/index.html'));

			res.render('home', {
				title : 'Control Panel',
				countries : CT,
				udata : req.session.user
			});
		}
	});
	
	app.post('/home', function(req, res){
		if (req.session.user == null){
			res.redirect('/');
		}	else{
			AM.updateAccount({
				id		: req.session.user._id,
				name	: req.body['name'],
				email	: req.body['email'],
				pass	: req.body['pass'],
				country	: req.body['country']
			}, function(e, o){
				if (e){
					res.status(400).send('error-updating-account');
				}	else{
					req.session.user = o;
			// update the user's login cookies if they exists //
					if (req.cookies.user != undefined && req.cookies.pass != undefined){
						res.cookie('user', o.user, { maxAge: 900000 });
						res.cookie('pass', o.pass, { maxAge: 900000 });	
					}
					res.status(200).send('ok');
				}
			});
		}
	});

	app.post('/logout', function(req, res){
		res.clearCookie('user');
		res.clearCookie('pass');
		req.session.destroy(function(e){ res.status(200).send('ok'); });
	})

// add new result  //
	app.post('/verify', function(req,res){
		VM.addNewResult(req.session.user.user,req.body,function(e){
			if (e){
				res.status(400).send(e);
			}	else{
				res.status(200).send('ok');
			}
		});
	});


// creating new accounts //
	
	app.get('/signup', function(req, res) {
		res.render('signup', {  title: 'Signup', countries : CT });
	});
	
	app.post('/signup', function(req, res){
		AM.addNewAccount({
			name 	: req.body['name'],
			email 	: req.body['email'],
			user 	: req.body['user'],
			pass	: req.body['pass'],
			country : req.body['country']
		}, function(e){
			if (e){
				res.status(400).send(e);
			}	else{
				res.status(200).send('ok');
			}
		});
	});

// password reset //

	app.post('/lost-password', function(req, res){
	// look up the user's account via their email //
		AM.getAccountByEmail(req.body['email'], function(o){
			if (o){
				EM.dispatchResetPasswordLink(o, function(e, m){
				// this callback takes a moment to return //
				// TODO add an ajax loader to give user feedback //
					if (!e){
						res.status(200).send('ok');
					}	else{
						for (k in e) console.log('ERROR : ', k, e[k]);
						res.status(400).send('unable to dispatch password reset');
					}
				});
			}	else{
				res.status(400).send('email-not-found');
			}
		});
	});

	app.get('/reset-password', function(req, res) {
		var email = req.query["e"];
		var passH = req.query["p"];
		AM.validateResetLink(email, passH, function(e){
			if (e != 'ok'){
				res.redirect('/');
			} else{
	// save the user's email in a session instead of sending to the client //
				req.session.reset = { email:email, passHash:passH };
				res.render('reset', { title : 'Reset Password' });
			}
		})
	});
	
	app.post('/reset-password', function(req, res) {
		var nPass = req.body['pass'];
	// retrieve the user's email from the session to lookup their account and reset password //
		var email = req.session.reset.email;
	// destory the session immediately after retrieving the stored email //
		req.session.destroy();
		AM.updatePassword(email, nPass, function(e, o){
			if (o){
				res.status(200).send('ok');
			}	else{
				res.status(400).send('unable to update password');
			}
		})
	});
	
// view & delete accounts //
	
	app.get('/print', function(req, res) {
		AM.getAllRecords( function(e, accounts){
			res.render('print', { title : 'Account List', accts : accounts });
		})
	});
	
	app.post('/delete', function(req, res){
		AM.deleteAccount(req.body.id, function(e, obj){
			if (!e){
				res.clearCookie('user');
				res.clearCookie('pass');
				req.session.destroy(function(e){ res.status(200).send('ok'); });
			}	else{
				res.status(400).send('record not found');
			}
	    });
	});
	
	app.get('/reset', function(req, res) {
		AM.delAllRecords(function(){
			res.redirect('/print');	
		});
	});
	
	app.get('*', function(req, res) { res.render('404', { title: 'Page Not Found'}); });

};
