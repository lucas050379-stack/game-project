class_name NvRig
extends RefCounted

## tools/rig_split.gd 가 만든다 — 손으로 고치지 마세요. 좌표는 원래 그림 픽셀, 원점 = 엉덩이 가운데(가랑이 줄 · 두 다리 사이).
## h = 전신 키(px) · feet = 엉덩이에서 발바닥까지 · 조각마다 tex_anchor = 그 그림 안에서 관절이 놓이는 픽셀 · at = 엉덩이에서 관절까지.
const PARTS := {
	"archer": {mode = "walk", h = 897, feet = 404, head = {tex_anchor = Vector2(90, 125), at = Vector2(-1, -368)}, torso = {tex_anchor = Vector2(109, 390), at = Vector2(0, 0)}, leg_b = {tex_anchor = Vector2(91, 0), at = Vector2(-91, -22)}, leg_f = {tex_anchor = Vector2(91, 0), at = Vector2(91, -22)}},
	"mage": {mode = "walk", h = 824, feet = 293, head = {tex_anchor = Vector2(109, 129), at = Vector2(116, -402)}, torso = {tex_anchor = Vector2(33, 422), at = Vector2(0, 0)}, leg_b = {tex_anchor = Vector2(26, 0), at = Vector2(-26, -20)}, leg_f = {tex_anchor = Vector2(128, 0), at = Vector2(128, -20)}},
	"warrior": {mode = "walk", h = 841, feet = 379, head = {tex_anchor = Vector2(94, 137), at = Vector2(11, -325)}, torso = {tex_anchor = Vector2(162, 346), at = Vector2(0, 0)}, leg_b = {tex_anchor = Vector2(86, 0), at = Vector2(-86, -21)}, leg_f = {tex_anchor = Vector2(87, 0), at = Vector2(87, -21)}},
}
