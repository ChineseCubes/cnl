require! {
  path
  gulp
  'gulp-util':       gutil
  'gulp-livescript': livescript
}

gulp.task \build ->
  gulp
    .src "#{path.resolve __dirname, 'src'}/**/*.ls"
    .pipe livescript!
    .pipe gulp.dest "#{path.resolve __dirname, 'lib'}/"

gulp.task \default <[build]>
