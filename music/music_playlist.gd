class_name MusicPlaylist extends Resource

@export var tracks: Array[AudioStream]

func get_track_name(index: int) -> String:
    if index >= 0 and index < tracks.size() and tracks[index] != null:
        return tracks[index].resource_path.get_file().get_basename().replace("-", "_").capitalize()
    return ""

func get_track_count() -> int:
    return tracks.size()

func get_stream(index: int) -> AudioStream:
    if index >= 0 and index < tracks.size():
        return tracks[index]
    return null
