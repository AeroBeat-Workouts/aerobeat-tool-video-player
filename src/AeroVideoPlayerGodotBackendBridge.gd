## Optional tool-owned bridge that wires the stable AeroVideoPlayerManager facade
## to the Godot vendor backend when the vendor addon is present in the runtime.
##
## This keeps downstream testbeds and demos on the repo-owned /src/ surface
## instead of preloading vendor scripts directly from scene code.
class_name AeroVideoPlayerGodotBackendBridge
extends RefCounted

const VERSION := "0.1.0"
const ManagerScript := preload("AeroVideoPlayerManager.gd")
const VENDOR_BACKEND_PATH := "res://addons/aerobeat-vendor-godot-video/src/AeroGodotVideoBackend.gd"

func create_backend(player_factory: Callable = Callable(), remote_source_resolver: Callable = Callable()) -> AeroVideoPlayerBackend:
	var backend_script := load(VENDOR_BACKEND_PATH)
	if backend_script == null:
		return null
	var backend: Variant = backend_script.new()
	if not (backend is AeroVideoPlayerBackend):
		return null
	if player_factory.is_valid() and backend.has_method("set_player_factory"):
		backend.set_player_factory(player_factory)
	if remote_source_resolver.is_valid() and backend.has_method("set_remote_source_resolver"):
		backend.set_remote_source_resolver(remote_source_resolver)
	return backend

func create_manager(player_factory: Callable = Callable(), remote_source_resolver: Callable = Callable()) -> AeroVideoPlayerManager:
	var manager := ManagerScript.new()
	manager.set_backend_factory(func() -> AeroVideoPlayerBackend:
		return create_backend(player_factory, remote_source_resolver)
	)
	var backend := create_backend(player_factory, remote_source_resolver)
	if backend != null:
		manager.set_backend(backend)
	return manager
