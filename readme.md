##Instalation & Run

    npm install
    node app

##Heroku deploy

Be sure to add the following Environment variables in your Heroku server in order to connect to your mongodb instance

    NODE_ENV = 'live'
    DB_USER = 'your current mongodb user'
    DB_PASS = 'your current mongodb pass'
    DB_HOST = 'your current mongodb host'
    DB_PORT = 'your current mongodb port'
    DB_NAME = 'your current mongodb database name'

this info can be found on your mongolab URI that has the following format

    mongodb://dbuser:dbpass@host1:port1,host2:port2/dbname

Example

    MONGODB_URI => mongodb://heroku_12345678:random_password@ds029017.mLab.com:29017/heroku_12345678

##Password Retrieval

To enable the password retrieval feature it is recommended that you create environment variables for your credentials instead of hard coding them into the [email dispatcher module](https://github.com/braitsch/node-login/blob/master/app/server/modules/email-dispatcher.js).

To do this on OSX you can simply add them to your .profile or .bashrc file.

	export EMAIL_HOST='smtp.gmail.com'
	export EMAIL_USER='your.email@gmail.com'
	export EMAIL_PASS='1234'


