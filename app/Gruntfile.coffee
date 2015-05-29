'use strict'

# Configuration

libs = [
	'bower/jquery/jquery.min'
	'bower/underscore/underscore'
	'bower/backbone/backbone'
	'bower/marionette/backbone.marionette'
	'bower/moment/moment.min'
	'bower/fullcalendar/fullcalendar.min'
	'bower/fullcalendar/gcal'
	'../build/dust-runtime'
	'../node_modules/6to5/runtime'
	'../node_modules/6to5/browser-polyfill'
]


structure = [
	'custom/**/*'
	'behaviors/**/*'
	'app'
	'base/**/*'
	'utils'
	'entities/**/*'
	'views'
	'components/**/*'
	'launch'
]


applications =
	main: structure
	admin: structure


builddir = 'build'
distdir = 'dist' # put the compiled code here
libdir = 'lib'
commondir = 'src/common'
tpldir = commondir+'/tpl'
jadedir = 'src/jade'

#releasesprites = distdir+'/img/sprites.png'



# create an object with a variable key
key = (k, p) ->
	o = {}
	o[k] = p
	o

module.exports = (grunt) ->
	#require('time-grunt') grunt
	require('load-grunt-tasks') grunt
	require(__dirname+'/grunt-6to5') grunt # Load my custom grunt task

	jadedata =
		config: require './util/config'
		env: process.env.NODE_ENV || 'development'

	inProduction = process.env.NODE_ENV == 'production'

	mapfiles = {}
	uglifyfiles = {}
	#coffeefiles = {}
	coffeefiles = []
	jsfiles = []
	stylefiles = {}
	watchscriptfiles = []
	jslintfiles = []
	coffeelintfiles = []

	jslintfiles.push 'src/common/**/*.js'
	coffeelintfiles.push 'src/common/**/*.coffee'
	watchscriptfiles.push 'src/common/**/*.coffee'
	watchscriptfiles.push 'src/common/**/*.js'

	for own name, files of applications

		coffeefiles.push
			expand: true
			cwd: 'src/'+name+'/script'
			src: ['**/*.coffee']
			dest: builddir+'/js/'+name
			ext: '.js'

		jsfiles.push
			expand: true
			cwd: 'src/'+name+'/script'
			src: ['**/*.js']
			dest: builddir+'/js/'+name
			ext: '.js'

		coffeelintfiles.push 'src/'+name+'/script/**/*.coffee'
		jslintfiles.push 'src/'+name+'/script/**/*.js'
		watchscriptfiles.push 'src/'+name+'/script/**/*.coffee'
		watchscriptfiles.push 'src/'+name+'/script/**/*.js'

		stylefiles[distdir+'/style/'+name+'.css'] = 'src/'+name+'/style/style.scss'
		#coffeefiles[builddir+'/'+name+'.core.js'] = []
		#coffeefilesdebug[distdir+'/js/'+name+'.min.js'] = []
		mapfiles[distdir+'/js/'+name+'.min.js'] = []

		#uglifyfiles[distdir+'/js/'+name+'.min.js'] = [builddir+'/'+name+'.core.js']
		uglifyfiles[distdir+'/js/'+name+'.min.js'] = []

		files.forEach (f, i) ->
			#coffeefiles[builddir+'/'+name+'.core.js'].push 'src/'+name+'/script/'+f+'.coffee'
			#coffeefilesdebug[distdir+'/js/'+name+'.min.js'][i] = 'src/'+name+'/script/'+f+'.coffee'

			mapfiles[distdir+'/js/'+name+'.min.js'].push builddir+'/js/'+name+'/'+f+'.js.map'
			uglifyfiles[distdir+'/js/'+name+'.min.js'].push builddir+'/js/'+name+'/'+f+'.js'


	libs.forEach (f, i) ->
		libs[i] = libdir+'/'+f+'.js'


	gruntconfig =

		pkg: grunt.file.readJSON 'package.json'


		uglify:

			release:
				options:
					mangle: false
					sourceMap: false
					#banner: '// <%= pkg.name %> - v<%= pkg.version %> - ' + '<%= grunt.template.today("yyyy-mm-dd") %> */\n'
				files: uglifyfiles

			# debug:
			# 	options:
			# 		mangle: false
			# 		beautify: true
			# 		compress: false
			# 		sourceMap: true
			# 	files: jsfiles

			libs:
				options:
					mangle: false
					sourceMap: false
					sourceRoot: "../../../.."
				files: key distdir+'/js/libs.min.js', libs

			common:
				options:
					mangle: false
					sourceMap: false
				files: key(distdir+'/js/common.min.js', [builddir+'/dust.js', builddir+'/common.js'])




		coffee:
			debug:
				options:
					sourceMap: true
				files: coffeefiles

			release:
				files: coffeefiles

			common:
				files: key(builddir+'/common.js', ['src/common/script/**/*.coffee'])

		'6to5':
			debug:
				options:
					sourceMap: true
					runtime: true
				files: jsfiles

			release:
				options:
					runtime: true
				files: jsfiles


		mapcat:
			default:
				files: mapfiles


		coffeelint:
			app:
				files:
					src: coffeelintfiles
				options:
					force: true
					no_tabs:
						level: 'ignore'
					indentation:
						level: 'ignore'
					max_line_length:
						level: 'ignore'

		jshint:
			app:
				files:
					src: jslintfiles
				options:
					force: true

					strict: true
					curly: true
					eqeqeq: true
					eqnull: true
					browser: true
					devel: true
					undef: true
					esnext: true
					noarg: true


		# sprite:
		# 	default:
		# 		src: spritedir+'/**/*.png'
		# 		destImg: releasesprites
		# 		destCSS: 'src/less/sprites.less'
		# 		algorithm: 'binary-tree'
		# 		cssFormat: 'less'
		# 		imgPath: '../img/sprites.png'
		# 		cssTemplate: 'src/less/sprites.less.mustache'


		# less:
		# 	development:
		# 		options:
		# 			sourceMap: true
		# 			sourceMapFileInline: true
		# 		files: stylefiles

		# 	production:
		# 		options:
		# 			#paths: [lessdir]
		# 			cleancss: true
		# 			compress: true

		# 		files: stylefiles

		sass:
			development:
				options:
					style: 'expanded'

				files: stylefiles

			production:
				options:
					sourcemap: 'none'
					style: 'compressed'
					noCache: true


		dust:
			default:
				options:
					wrapper: false
					basePath: tpldir
					runtime: false
				files: key(builddir+'/dust.js', [tpldir+'/**/*.dust'])

			runtime:
				options:
					wrapper: false
					basePath: tpldir
					runtime: true
				files: key(builddir+'/dust.js', [tpldir+'/**/*.dust'])


		jade:
			default:
				options:
					pretty: true
					data: jadedata

				files: [
					expand: true
					cwd: jadedir
					src: ['**/*.jade']
					dest: builddir+'/html'
					ext: '.html'
					extDot: 'last'
				]


		htmlmin:
			options:
				collapseBooleanAttributes: inProduction
				collapseWhitespace: inProduction
				removeComments: inProduction
				removeAttributeQuotes: inProduction
				removeCommentsFromCDATA: inProduction
				removeEmptyAttributes: inProduction
				removeOptionalTags: false
				removeRedundantAttributes: inProduction
				useShortDoctype: true

			jade:
				files: [
					expand: true
					cwd: builddir+'/html'
					src: ['**/*.html']
					dest: distdir
				]

		copy:
			html:
				files: [
					expand: true
					cwd: builddir+'/html'
					src: ['**/*.html']
					dest: distdir
				]

		clean:
			build: [builddir]

			js: [builddir+'/js']
			jade: [builddir+'/jade']
			dist: [distdir]

		bower:
			default:
				options:
					targetDir: libdir+'/bower'
					cleanTargetDir: true
					bowerOptions:
						production: true

		watch:
			options:
				spawn: false
				debounceDelay: 250

			#	gruntfile:
			#		files: ['Gruntfile.coffee']


			jade:
				files: [jadedir+'/**/*.jade', '../config.json']
				tasks: [
					'build:jade'
				]

			sass:
			#	files: ['src/**/*.less', spritedir+'/**/*.png']
				files: ['src/*/style/**/*.scss']
				tasks: [
					'build:sass'
				]
				options:
					livereload: true

			# env specific watchers below

		concurrent:
			options:
				logConcurrentOutput: true

			production: [
				'build:release'
				'build:jade'
				'build:sass'
			]
			development: [
				'build:debug'
				'build:jade'
				'build:sass'
			]



	if inProduction
		gruntconfig.watch.core =
			files: watchscriptfiles
			tasks: [
				'clean:js'
				'coffee:release'
				'6to5:release'
				'uglify:release'
				'lint'
			]

		gruntconfig.watch.tpl =
			files: [tpldir+'/**/*.dust']
			tasks: [
				'dust:default'
				'coffee:common'
				'uglify:common'
			]


	else
		gruntconfig.watch.core =
			files: watchscriptfiles
			tasks: [
				'clean:js'
				'debug'
				'lint'
			]

		gruntconfig.watch.tpl =
			files: [tpldir+'/**/*.dust']
			tasks: [
				'dust:default'
				'coffee:common'
				'uglify:common'
			]

		gruntconfig.watch.commoncoffee =
			files: [commondir+'/script/**/*.coffee', commondir+'/script/**/*.js']
			tasks: [
				'coffee:common'
				'uglify:common'
			]

	grunt.initConfig gruntconfig




	if inProduction
		grunt.registerTask 'build:default', [
			'build:production'
		]

		grunt.registerTask 'build:jade', [
			'jade:default'
			'htmlmin:jade'
		]

		grunt.registerTask 'build:sass', [
		#	'sprite'
			'sass:production'
		]

	else
		grunt.registerTask 'build:default', [
			'build:development'
		]

		grunt.registerTask 'build:jade', [
			'jade:default'
			'copy:html'
		]

		grunt.registerTask 'build:sass', [
		#	'sprite'
			'sass:development'
		]

	grunt.registerTask 'default', ['build:default']
	grunt.registerTask 'build', ['default']

	grunt.registerTask 'lint', [
		'jshint'
		'coffeelint'
	]

	grunt.registerTask 'edit', [
		'build:default'
		'watch'
	]

	grunt.registerTask 'libs', [
		'uglify:libs'
	]

	grunt.registerTask 'debug', [
		'6to5:debug'
		'coffee:debug'
		'mapcat'
	]

	grunt.registerTask 'build:debug', [
		'dust:runtime'
		'libs'
		'coffee:common'
		'uglify:common'
		'debug'
	]

	grunt.registerTask 'build:release', [
		'dust:runtime'
		'libs'
		'coffee:common'
		'uglify:common'
		'coffee:release'
		'6to5:release'
		'uglify:release'
	]

	grunt.registerTask 'build:production', [
		'clean'
		#'concurrent:production'
		'build:release'
		'build:jade'
		'build:sass'
		'lint'
	]

	grunt.registerTask 'build:development', [
		'clean'
		#'concurrent:development'
		'build:debug'
		'build:jade'
		'build:sass'
		'lint'
	]
