using UnityEngine;
using System.Collections;
using System;

[ExecuteInEditMode]
public class LightBleeding : MonoBehaviour 
{
	[Range(0, 1)]
	public float blendSpeed = 0.1f;
	public float normalOffset = 0f;
	public float vplMergeLimit = 1;

	[Range(0, 3)]
	public float colorStrength = 1;
	public int voxelSize = 32;
	public int propogationSteps = 8;
	public int fluxRes = 256; 

	public Bounds volumeBounds = new Bounds(Vector3.zero, Vector3.one);
	public Shader depthShader;
	public Shader voxelShader;
	public bool on = true;
	public bool downSampleRSM = false;
	public bool debugTextures = false;
	public bool multiplyColor = false;

	[HideInInspector]
	public bool hemisphericalBlur = false;

	public bool pointSample = false;

	public Camera targetCamera;

	private Material _voxelMaterial;
	private Material VoxelMaterial
	{
		get
		{
			if(_voxelMaterial == null)
			{
				_voxelMaterial = new Material(voxelShader);
				_voxelMaterial.hideFlags = HideFlags.HideAndDontSave;
			}
			return _voxelMaterial;
		}
	}

	private RenderTexture _albedo;
	private RenderTexture Albedo
	{
		get
		{
			if (_albedo != null && fluxRes != _albedo.height)
			{
				DestroySafe(_albedo);
			}
			if(_albedo == null)
			{
				_albedo = new RenderTexture(fluxRes, fluxRes, 24, RenderTextureFormat.ARGB32);
				_albedo.hideFlags = HideFlags.HideAndDontSave;
				_albedo.wrapMode = TextureWrapMode.Clamp;
				_albedo.useMipMap = false;
			}
			return _albedo;
		}
	}

	private RenderTexture _prevTexture;
	private RenderTexture PrevTexture
	{
		get
		{
			if (_prevTexture != null && voxelSize != _prevTexture.height)
			{
				DestroySafe(_prevTexture);
			}
			if(_prevTexture == null)
			{
				_prevTexture = new RenderTexture(voxelSize * voxelSize, voxelSize, 0);
				_prevTexture.hideFlags = HideFlags.HideAndDontSave;
				_voxelTexture.filterMode = FilterMode.Point;
				_prevTexture.wrapMode = TextureWrapMode.Clamp;
				_prevTexture.useMipMap = false;
			}
			return _prevTexture;
		}
	}

	private RenderTexture _voxelTexture;
	private RenderTexture VoxelTexture
	{
		get
		{
			if (_voxelTexture != null && voxelSize != _voxelTexture.height)
			{
				DestroySafe(_voxelTexture);
			}
			if(_voxelTexture == null)
			{
				_voxelTexture = new RenderTexture(voxelSize * voxelSize, voxelSize, 0);
				_voxelTexture.hideFlags = HideFlags.HideAndDontSave;
				_voxelTexture.filterMode = FilterMode.Point;
				_voxelTexture.wrapMode = TextureWrapMode.Clamp;
				_voxelTexture.useMipMap = false;
			}
			return _voxelTexture;
		}
	}

	private void DestroySafe(UnityEngine.Object obj)
	{
		if(obj != null)
		{
			if(Application.isPlaying)
			{
				Destroy(obj);
			}
			else
			{
				DestroyImmediate(obj);
			}
			obj = null;
		}
	}

	private void OnEnable()
	{
		camera.depthTextureMode |= DepthTextureMode.DepthNormals;
	}

	private Vector3 SnapVector(Vector3 vec)
	{
		return new Vector3(SnapNumber(vec.x), SnapNumber(vec.y), SnapNumber(vec.z));
	}

	private float SnapNumber(float number)
	{
		var worldUnitsPerTexel =  (camera.orthographicSize * 2f) / Albedo.width;
		number /= worldUnitsPerTexel;
		number = Mathf.Round(number);
		number *= worldUnitsPerTexel;
		return number;
	}

	private RenderTexture GetTempPointTexture(int size)
	{
		var tex = RenderTexture.GetTemporary(size, size, 0);
		tex.filterMode = FilterMode.Point;
		return tex;
	}

	private void RenderMRT(RenderBuffer[] renderBuffers, RenderBuffer depthBuffer)
	{
		Graphics.SetRenderTarget(renderBuffers, depthBuffer);
		GL.Clear(false, true, Color.clear);
		GL.PushMatrix();
		GL.LoadOrtho();
		VoxelMaterial.SetPass(6);
		GL.Begin(GL.QUADS);
		GL.TexCoord2(0.0f, 0.0f); GL.Vertex3(0.0f, 0.0f, 0.1f);
		GL.TexCoord2(1.0f, 0.0f); GL.Vertex3(1.0f, 0.0f, 0.1f);
		GL.TexCoord2(1.0f, 1.0f); GL.Vertex3(1.0f, 1.0f, 0.1f);
		GL.TexCoord2(0.0f, 1.0f); GL.Vertex3(0.0f, 1.0f, 0.1f);
		GL.End();
		GL.PopMatrix();
	}
		
	private void Update()
	{
		if(multiplyColor)
		{
			Shader.EnableKeyword("MULTIPLY_COLOR");
			Shader.DisableKeyword("MULTIPLY_COLOR_OFF");
		} 
		else
		{
			Shader.DisableKeyword("MULTIPLY_COLOR");
			Shader.EnableKeyword("MULTIPLY_COLOR_OFF");
		}

		if(on)
		{
			Shader.EnableKeyword("ENABLE_BLEED");
			Shader.DisableKeyword("DISABLE_BLEED");
			if(pointSample)
			{
				Shader.EnableKeyword("VOXEL_POINT_SAMPLE");
				Shader.DisableKeyword("VOXEL_TRILINEAR_SAMPLE");
			}
			else
			{
				Shader.DisableKeyword("VOXEL_POINT_SAMPLE");
				Shader.EnableKeyword("VOXEL_TRILINEAR_SAMPLE");
			}
		}
		else
		{
			Shader.DisableKeyword("ENABLE_BLEED");
			Shader.EnableKeyword("DISABLE_BLEED");
			return;
		}

		if(camera.isOrthoGraphic)
		{
			Shader.EnableKeyword("ORTHOGRAPHIC");
			Shader.DisableKeyword("PERSPECTIVE");
		}
		else
		{
			Shader.DisableKeyword("ORTHOGRAPHIC");
			Shader.EnableKeyword("PERSPECTIVE");
		}

		var points = RecalculateFrustrumPoints(camera);
		for(int i = 0; i < points.Length; i++)
		{
			points[i] = SnapVector(points[i]);
		}
		
		if(targetCamera != null)
		{
			var pts = RecalculateFrustrumPoints(targetCamera);
			var centre = Vector3.zero;
			foreach(var pt in pts)
			{
				centre += targetCamera.transform.localToWorldMatrix.MultiplyPoint(pt);
			}
			centre /= pts.Length;
			centre = SnapVector(centre);
			
			var bds = new Bounds(centre, Vector3.zero);
			foreach(var pt in pts)
			{
				var worldPoint = targetCamera.transform.localToWorldMatrix.MultiplyPoint(pt);
				worldPoint = SnapVector(worldPoint);
				bds.Encapsulate(worldPoint);
			}
			
			volumeBounds = bds;
			transform.position = SnapVector(volumeBounds.center - transform.forward * 100);
		}

		voxelSize = Mathf.Clamp(voxelSize, 4, 64);
		propogationSteps = Mathf.Clamp(propogationSteps, 1, voxelSize);

		Shader.SetGlobalVector("_LightDir",  transform.forward);
		Shader.SetGlobalFloat("_LPVDimensions", voxelSize);
		Shader.SetGlobalFloat("_LPVDimensionsSquared", voxelSize * voxelSize);
		Shader.SetGlobalVector("_LPV_AABBMin", volumeBounds.min);
		Shader.SetGlobalVector("_LPV_AABBMax", volumeBounds.max);
		Shader.SetGlobalVector("_LPV_Extents", volumeBounds.max - volumeBounds.min);
		Shader.SetGlobalTexture("_VoxelTex", VoxelTexture);
		
		VoxelMaterial.SetFloat("_LightCameraNear", camera.nearClipPlane);
		VoxelMaterial.SetFloat("_LightCameraFar", camera.farClipPlane);
		VoxelMaterial.SetFloat("_NormalOffset", normalOffset);
		VoxelMaterial.SetFloat("_FallOff", colorStrength * 3);
		VoxelMaterial.SetFloat("_BlendSpeed", Time.renderedFrameCount == 1 ? 1 : blendSpeed);
		VoxelMaterial.SetVector("_FrustrumPoints", new Vector4(
			points[4].x,
			points[5].x,
			points[5].y,
			points[6].y));
		VoxelMaterial.SetMatrix("_WorldToView", camera.worldToCameraMatrix);
		VoxelMaterial.SetMatrix("_ViewToWorld", camera.cameraToWorldMatrix);

		var origPos = transform.position;
		transform.position = SnapVector(origPos);
		var origOrthoSize = camera.orthographicSize;
		camera.orthographicSize = SnapNumber(camera.orthographicSize);

		camera.targetTexture = Albedo;
		Shader.EnableKeyword("DISABLE_BLEED");
		Shader.DisableKeyword("ENABLED_BLEED");
		camera.Render();
		Shader.DisableKeyword("DISABLE_BLEED");
		Shader.EnableKeyword("ENABLED_BLEED");
		VoxelMaterial.SetTexture("_MainTex", Albedo);

		transform.position = origPos;
		camera.orthographicSize = origOrthoSize;

		RenderTexture depthHalf = null;
		RenderTexture depthQuarter = null;
		RenderTexture albedoHalf = null;
		RenderTexture albedoQuarter = null;

		if(downSampleRSM)
		{
			VoxelMaterial.SetFloat("_VPLMergeLimit", vplMergeLimit);

			albedoHalf = GetTempPointTexture(Albedo.width / 2);
			depthHalf = GetTempPointTexture(Albedo.width / 2);

			albedoQuarter = GetTempPointTexture(Albedo.width / 4);
			depthQuarter = GetTempPointTexture(Albedo.width / 4);

			RenderMRT(new RenderBuffer [] { albedoHalf.colorBuffer, depthHalf.colorBuffer }, albedoHalf.depthBuffer);
			RenderMRT(new RenderBuffer [] { albedoQuarter.colorBuffer, depthQuarter.colorBuffer }, albedoQuarter.depthBuffer);

			VoxelMaterial.SetTexture("_MainTex", albedoQuarter);
			VoxelMaterial.SetTexture("_CameraDepthNormalsTextureManual", depthQuarter);

			Shader.EnableKeyword("DEPTH_TEXTURE_MANUAL");
			Shader.DisableKeyword("DEPTH_TEXTURE_UNITY");
		}
		else
		{
			Shader.DisableKeyword("DEPTH_TEXTURE_MANUAL");
			Shader.EnableKeyword("DEPTH_TEXTURE_UNITY");
		}

		Shader.EnableKeyword("SAMPLE_COLOR");
		Shader.DisableKeyword("SAMPLE_NORMAL");

		RenderTexture.active = VoxelTexture;
		GL.Clear(false, true, Color.clear);
		RenderVolume(VoxelMaterial, 0, voxelSize);

		RenderTexture normalTex = null;
		if(hemisphericalBlur)
		{
			Shader.DisableKeyword("SAMPLE_COLOR");
			Shader.EnableKeyword("SAMPLE_NORMAL");
			normalTex = RenderTexture.GetTemporary(voxelSize * voxelSize, voxelSize, 0);
			RenderTexture.active = normalTex;
			GL.Clear(false, true, Color.clear);
			RenderVolume(VoxelMaterial, 0, voxelSize);
			VoxelMaterial.SetTexture("_NormalTex", normalTex);
		}

		// Propogate or spatial blur
		var blurBuffer = RenderTexture.GetTemporary(voxelSize * voxelSize, voxelSize, 0);
		if(hemisphericalBlur)
		{
			for(int k = 0; k < propogationSteps; k++)
			{
				Graphics.Blit(VoxelTexture, blurBuffer, VoxelMaterial, 7);
				VoxelTexture.DiscardContents();
				Graphics.Blit(blurBuffer, VoxelTexture, VoxelMaterial, 7);
				blurBuffer.DiscardContents();
				Graphics.Blit(VoxelTexture, blurBuffer, VoxelMaterial, 7);
				VoxelTexture.DiscardContents();
				Graphics.Blit(blurBuffer, VoxelTexture);
				blurBuffer.DiscardContents();
			}
			RenderTexture.ReleaseTemporary(normalTex);
		}
		else
		{
			for(int k = 0; k < propogationSteps; k++)
			{
				Graphics.Blit(VoxelTexture, blurBuffer, VoxelMaterial, 1);
				VoxelTexture.DiscardContents();
				Graphics.Blit(blurBuffer, VoxelTexture, VoxelMaterial, 2);
				blurBuffer.DiscardContents();
				Graphics.Blit(VoxelTexture, blurBuffer, VoxelMaterial, 3);
				VoxelTexture.DiscardContents();
				Graphics.Blit(blurBuffer, VoxelTexture);
				blurBuffer.DiscardContents();
			}
		}
		RenderTexture.ReleaseTemporary(blurBuffer);

		if(Application.isPlaying)
		{
			Shader.EnableKeyword("FRAME_BLEND");
			Shader.DisableKeyword("FRAME_BLEND_DISABLED");
			VoxelMaterial.SetTexture("_PrevTex", PrevTexture);
			var temp = RenderTexture.GetTemporary(voxelSize * voxelSize, voxelSize, 0);
			Graphics.Blit(VoxelTexture, temp, VoxelMaterial, 4);
			Graphics.Blit(temp, VoxelTexture);
			Graphics.Blit(temp, PrevTexture);
			RenderTexture.ReleaseTemporary(temp);
		}
		else
		{
			Shader.DisableKeyword("FRAME_BLEND");
			Shader.EnableKeyword("FRAME_BLEND_DISABLED");
		}

		if(downSampleRSM)
		{
			RenderTexture.ReleaseTemporary(depthHalf);
			RenderTexture.ReleaseTemporary(depthQuarter);
			RenderTexture.ReleaseTemporary(albedoHalf);
			RenderTexture.ReleaseTemporary(albedoQuarter);
		}
	}

#if UNITY_EDITOR
	private void OnGUI()
	{
		if(debugTextures)
		{
			GUI.DrawTexture(new Rect(-VoxelTexture.width / 2, 0, VoxelTexture.width, VoxelTexture.height), VoxelTexture);
			GUI.DrawTexture(new Rect(0, VoxelTexture.height, 128, 128), Albedo);
		}
	}
#endif

	private void OnDrawGizmos()
	{
		Gizmos.DrawWireCube(volumeBounds.center, volumeBounds.size);
	}

	private void OnDisable()
	{
		DestroySafe(_voxelTexture);
		DestroySafe(_prevTexture);
		DestroySafe(_voxelMaterial);
	}

	private void OnDestroy()
	{
		DestroySafe(_voxelTexture);
		DestroySafe(_prevTexture);
		DestroySafe(_voxelMaterial);
	}

	private void GenerateQuad(Vector3[] verts, Vector2[] uvs, int[] tris, int x, int y, int offset, int offsetTris)
	{
		var vec = new Vector3(x, y, 0);
		verts[offset + 0] = vec;
		verts[offset + 1] = vec;
		verts[offset + 2] = vec;
		verts[offset + 3] = vec;

		uvs[offset + 0] = Vector2.zero;
		uvs[offset + 1] = Vector2.up;
		uvs[offset + 2] = Vector2.right + Vector2.up;
		uvs[offset + 3] = Vector2.right;

		tris[offsetTris + 0] = offset + 0;
		tris[offsetTris + 1] = offset + 1;
		tris[offsetTris + 2] = offset + 2;

		tris[offsetTris + 3] = offset + 0;
		tris[offsetTris + 4] = offset + 2;
		tris[offsetTris + 5] = offset + 3;
	}

	//private Mesh _voxelMesh = null;

	private void RenderVolume(Material material, int pass, int voxelSize)
	{
//		if(_voxelMesh == null)
//		{
//			_voxelMesh = new Mesh();
//			_voxelMesh.hideFlags = HideFlags.HideAndDontSave;
//		}
//		
//		if(_voxelMesh.vertices == null || _voxelMesh.vertices.Length != voxelSize * voxelSize * 4)
//		{
//			_voxelMesh.Clear();	
//			var verts = new Vector3[voxelSize * voxelSize * 4];
//			var uvs = new Vector2[voxelSize * voxelSize * 4];
//			var tris = new int[verts.Length / 4 * 6];
//			var offset = 0;
//			var offsetTris = 0;
//			for(var y = 0; y < voxelSize; y ++)
//			{
//				for(var x = 0; x < voxelSize; x ++)
//				{
//					GenerateQuad(verts, uvs, tris, x, y, offset, offsetTris);
//					offset += 4;
//					offsetTris += 6;
//				}
//			}
//
//			_voxelMesh.vertices = verts;
//			_voxelMesh.uv = uvs;
//			_voxelMesh.normals = new Vector3[verts.Length];
//			_voxelMesh.triangles = tris;
//		}
//		GL.PushMatrix();
//		if(material.SetPass(pass))
//		{
//			GL.LoadPixelMatrix(0, voxelSize * voxelSize, 0, voxelSize);
//			Graphics.DrawMeshNow(_voxelMesh, Vector3.zero, Quaternion.identity);
//		}
//		GL.PopMatrix();

		GL.PushMatrix();
		material.SetPass(pass);
		GL.LoadPixelMatrix(0, voxelSize * voxelSize, 0, voxelSize);
		GL.Begin(GL.QUADS);
		for(var y = 0; y < voxelSize; y ++)
		{
			for(var x = 0; x < voxelSize; x ++)
			{
				GL.TexCoord2(0, 0);
				GL.Vertex3(x, y, 0);
				
				GL.TexCoord2(0, 1);
				GL.Vertex3(x, y, 0);
				
				GL.TexCoord2(1, 1);
				GL.Vertex3(x, y, 0);
				
				GL.TexCoord2(1, 0);
				GL.Vertex3(x, y, 0);
			}
		}
		GL.End();
		GL.PopMatrix();
	}

	private Vector3[] RecalculateFrustrumPoints(Camera cam)
	{
		var frustrumPoints = new Vector3[8];
		var far = cam.farClipPlane;
		var near = cam.nearClipPlane;
		var aspectRatio = cam.aspect;
		
		if(cam.isOrthoGraphic)
		{
			var orthoSize = cam.orthographicSize;

			frustrumPoints[0] = new Vector3(orthoSize, orthoSize, near);
			frustrumPoints[1] = new Vector3(-orthoSize, orthoSize, near);
			frustrumPoints[2] = new Vector3(-orthoSize, -orthoSize, near);
			frustrumPoints[3] = new Vector3(orthoSize, -orthoSize, near);
			
			frustrumPoints[4] = new Vector3(orthoSize, orthoSize, far);
			frustrumPoints[5] = new Vector3(-orthoSize, orthoSize, far);
			frustrumPoints[6] = new Vector3(-orthoSize, -orthoSize, far);
			frustrumPoints[7] = new Vector3(orthoSize, -orthoSize, far);
		} 
		else
		{
			var hNear = 2 * Mathf.Tan((cam.fieldOfView * 0.5f) * Mathf.Deg2Rad) * near;
			var wNear = hNear * aspectRatio;
			
			var hFar = 2 * Mathf.Tan((cam.fieldOfView * 0.5f) * Mathf.Deg2Rad) * far;
			var wFar = hFar * aspectRatio;
			
			var fc = Vector3.forward * far;
			var ftl = fc + (Vector3.up * hFar / 2) - (Vector3.right * wFar / 2);
			var ftr = fc + (Vector3.up * hFar / 2) + (Vector3.right * wFar / 2);
			var fbl = fc - (Vector3.up * hFar / 2) - (Vector3.right * wFar / 2);
			var fbr = fc - (Vector3.up * hFar / 2) + (Vector3.right * wFar / 2);
			
			var nc = Vector3.forward * near;
			var ntl = nc + (Vector3.up * hNear / 2) - (Vector3.right * wNear / 2);
			var ntr = nc + (Vector3.up * hNear / 2) + (Vector3.right * wNear / 2);
			var nbl = nc - (Vector3.up * hNear / 2) - (Vector3.right * wNear / 2);
			var nbr = nc - (Vector3.up * hNear / 2) + (Vector3.right * wNear / 2);
			
			frustrumPoints[0] = ntr;
			frustrumPoints[1] = ntl;
			frustrumPoints[2] = nbr;
			frustrumPoints[3] = nbl;
			
			frustrumPoints[4] = ftr;
			frustrumPoints[5] = ftl;
			frustrumPoints[6] = fbl;
			frustrumPoints[7] = fbr;			
		}
		
		return frustrumPoints;
	}
}
