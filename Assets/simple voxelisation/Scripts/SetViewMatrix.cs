using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class SetViewMatrix : MonoBehaviour 
{
	private void OnWillRenderObject()
	{
		Shader.SetGlobalMatrix("_InvWorld2Camera", Camera.current.worldToCameraMatrix.inverse);
	}
}
