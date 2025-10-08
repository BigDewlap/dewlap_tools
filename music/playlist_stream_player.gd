@tool
class_name PlaylistStreamPlayer extends AudioStreamPlayer

@export_group("Actions")
@export_tool_button("stop") var stop_playing = stop
@export_tool_button("play") var start_playing = play
@export_tool_button("toggle_pause") var pause = toggle_pause
@export_tool_button("next") var next = play_next_song
@export_tool_button("prev") var prev = play_previous_song

@export var _tracks: Array[AudioStream]
@export var _excluded_track_names: Array[StringName]

@export var shuffle:bool = false:
    set(value):
        var update_playlist:bool = shuffle != value
        shuffle = value
        if update_playlist:
            _update_playlist()
    get():
        return shuffle

@export var loop:bool = false

var _playlist:Dictionary[StringName, AudioStream]

var _current_track_index:int = 0

signal song_started
signal song_loaded

func _get_configuration_warnings() -> PackedStringArray:
    if stream:
        return ["Steam should not be set, will be controlled by playlist"]
    return []

func _ready():
    _update_playlist()
    _current_track_index = 0
    finished.connect(_on_finished)
    if _playlist.size() > 0:
        stream = _playlist.values()[_current_track_index]
        if !Engine.is_editor_hint() && autoplay:
            play()

func _update_playlist() -> void:
    _playlist = {}
    var temp_tracks := _tracks.duplicate()
    if shuffle:
        temp_tracks.shuffle()
    for track:AudioStream in temp_tracks:
        var track_name = get_track_name(track)
        if !_excluded_track_names.has(track_name):
            _playlist.set(track_name, track)

func set_tracks(tracks:Array[AudioStream]) -> void:
    _tracks = tracks
    _update_playlist()

func get_excluded_track_names() -> Array[StringName]:
    return _excluded_track_names

func set_excluded_track_names(track_names:Array[StringName]) -> void:
    _excluded_track_names = track_names
    _update_playlist()

func play_track(index:int) -> void:
    if(_playlist.size() < 1):
        stop()
    _current_track_index = index % _playlist.size()
    stream = _playlist.values()[_current_track_index]
    play()
    song_started.emit()

func play_track_by_name(name:StringName) -> void:
    stream = _playlist.get(name)
    play()
    song_started.emit()

func toggle_pause() -> void:
    if has_stream_playback():
        stream_paused = !stream_paused
    else:
        play_track(_current_track_index)

func play_next_song() -> void:
    if(_playlist.size() < 1):
        stop()
    var index = (_current_track_index + 1) % _playlist.size()
    play_track(index)

func play_previous_song() -> void:
    if(_playlist.size() < 1):
        stop()
    var index = (_current_track_index - 1) % _playlist.size()
    play_track(index)

func get_current_track_name() -> String:
    return get_track_name(stream)

func _on_finished() -> void:
    if loop || _current_track_index < _playlist.size():
        play_next_song()

func get_track_name(audio_stream: AudioStream) -> String:
    if audio_stream:
        return audio_stream.resource_path.get_file().get_basename().replace("-", "_").capitalize()
    return ""

func get_all_track_names() -> Array[StringName]:
    var track_names:Array[StringName] = []
    for track:AudioStream in _tracks:
        track_names.push_back(get_track_name(track))
    return track_names
