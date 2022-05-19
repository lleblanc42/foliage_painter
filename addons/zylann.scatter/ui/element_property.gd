class_name ElementProperty

#密度
var density:float = 0.0
#间距
var radius:float = 0.0
#高度随机偏移
#最小偏移
var yOffsetMin:float = 0.0
#最大偏移
var yOffsetMax:float = 0.0
#最小缩放
var scaleMin:float = 1.0
#最大缩放
var scaleMax:float = 1.0
#最小旋转角度 -180 ~180
var rotateMin:float = 0.0
#最大旋转角度-180 ~180
var rotateMax:float = 0.0

func update(key:String,value:float):
	match key:
		"density":
			density = value
		"radius":
			radius = value
		"yOffsetMin":
			yOffsetMin = value
		"yOffsetMax":
			yOffsetMax = value
		"scaleMin":
			scaleMin = value
		"scaleMax":
			scaleMax = value
		"rotateMin":
			rotateMin = value
		"rotateMax":
			rotateMax = value
