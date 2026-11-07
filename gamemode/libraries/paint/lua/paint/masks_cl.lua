local masks = {}
do
	local w, h = ScrW(), ScrH()
	local rt = GetRenderTargetEx('paint.masksRT', w, h, RT_SIZE_LITERAL, MATERIAL_RT_DEPTH_NONE, 1 + 256, 0, IMAGE_FORMAT_BGRA8888)

	local material = CreateMaterial( "paint.masksMaterial", "UnlitGeneric", {
	  ["$basetexture"] = "paint.masksRT",
	  ["$translucent"] = 1,
	})

	local rectMesh

	local function createRectMesh()
		if rectMesh then
			rectMesh:Destroy()
		end

		rectMesh = Mesh(material)

		local color = Color(255, 255, 255)
		paint.rects.generateRectMesh(rectMesh, 0, 0, w, h, {color, color, color, color}, 0, 0, 1, 1)
	end

	createRectMesh()

	hook.Add('OnScreenSizeChanged', 'paint.masks', function(_, _, newW, newH)
		w, h = newW, newH

		rt:Download()
		rt = GetRenderTargetEx('paint.masksRT', w, h, RT_SIZE_LITERAL, MATERIAL_RT_DEPTH_NONE, 1 + 256, 0, IMAGE_FORMAT_BGRA8888)

		createRectMesh()
	end)

	local renderPushRenderTarget = render.PushRenderTarget
	local renderPopRenderTarget = render.PopRenderTarget
	local renderClear = render.Clear
	local renderOverrideAlphaWriteEnable = render.OverrideAlphaWriteEnable

	local camStart2D
	do
		local camStart = cam.Start
		local data = {type = '2d'}

		function camStart2D()
			camStart(data)
		end
	end
	local camEnd2D = cam.End2D

	masks.source = function()
		renderPushRenderTarget(rt)
		renderOverrideAlphaWriteEnable(true, true)
		renderClear(0, 0, 0, 0)

		camStart2D()
	end

	masks.destination = function()
		camEnd2D()
		renderOverrideAlphaWriteEnable(true, false)
		camStart2D()
	end

	local setMaterial = render.SetMaterial
	local drawMesh = rectMesh.Draw

	masks.stop = function()
		camEnd2D()
		renderPopRenderTarget()

		setMaterial(material)
		drawMesh(rectMesh)
	end
end

paint.masks = masks