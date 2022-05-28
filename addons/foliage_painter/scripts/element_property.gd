class_name ElementProperty

#密度 (10m x 10m area number)
var density:float = 10.0
#间距(cm)
var radius:float = 30.0
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
			#最大值不能小于最小值
			if yOffsetMax < yOffsetMin:
				yOffsetMax = yOffsetMin
		"yOffsetMax":
			yOffsetMax = value
		"scaleMin":
			scaleMin = value
			#最大值不能小于最小值
			if scaleMax < scaleMin:
				scaleMax = scaleMin
		"scaleMax":
			scaleMax = value
		"rotateMin":
			rotateMin = value
			#最大值不能小于最小值
			if rotateMax < rotateMin:
				rotateMax = scaleMin
		"rotateMax":
			rotateMax = value
