extends SceneTree
## Renders the low-poly figures (front, side, back) to a PNG, for checking them against the
## turnarounds in mockups/lowpoly:
##   xvfb-run -a godot --path game --rendering-driver opengl3 -s res://tests/art/figure_shots.gd -- <out.png>


func _init() -> void:
	var out := "user://figures.png"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	var vp := SubViewport.new()
	vp.size = Vector2i(1500, 1000)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#101014")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#3a4060")
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.7, 0)
	key.light_color = Color("#ffb36a")
	key.light_energy = 1.4
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.8, 0)
	rim.light_color = Color("#ff8a3a")
	rim.light_energy = 1.2
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 9.0)
	cam.fov = 40
	vp.add_child(cam)
	var figs := [Figures3D.mamuthone(), Figures3D.mamuthone(), Figures3D.mamuthone(), Figures3D.issohadore(), Figures3D.issohadore()]
	var xs := [-4.4, -2.2, 0.0, 2.2, 4.4]
	var rots := [0.0, PI * 0.5, PI, 0.0, PI * 0.5]
	for i in figs.size():
		var f: Node3D = figs[i]
		f.position = Vector3(xs[i], 0, 0)
		f.rotation.y = rots[i]
		vp.add_child(f)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(out)
	print("figures written to ", out)
	quit()
