using UnityEngine;
using System.Collections;

public class RotateObject : MonoBehaviour 
{
	[SerializeField]
	private float speed = 50;

	[SerializeField]
	private string[] axisDef = new string[] { "Vertical", null, "Horizontal" };

	private LightBleeding _lightBleeding;

	public Transform altitude;

	public Transform rotation;

	private void Start()
	{
		_lightBleeding = GameObject.FindObjectOfType<LightBleeding>();
	}

	private void OnEnable()
	{
		StartCoroutine(Run());
	}

	private IEnumerator Run () 
	{
		var yieldFrame = new WaitForEndOfFrame();
		while(true)
		{

			transform.Rotate(
				(string.IsNullOrEmpty(axisDef[0])) ? 0 : speed * Input.GetAxis(axisDef[0]) * Time.deltaTime,
			 	(string.IsNullOrEmpty(axisDef[1])) ? 0 : speed * Input.GetAxis(axisDef[1]) * Time.deltaTime,
				(string.IsNullOrEmpty(axisDef[2])) ? 0 : speed * Input.GetAxis(axisDef[2]) * Time.deltaTime,
				Space.World);
				

			yield return yieldFrame;
		}
	}

	private void OnGUI()
	{
		_lightBleeding.on = GUILayout.Toggle(_lightBleeding.on, "Light bleeding On");
		_lightBleeding.pointSample = GUILayout.Toggle(_lightBleeding.pointSample, "Point Sampling On");
		GUILayout.Label("Bounce Strength " + _lightBleeding.colorStrength.ToString("0.0"));
		_lightBleeding.colorStrength = GUILayout.HorizontalSlider(_lightBleeding.colorStrength, 0f, 1.0f);
		GUILayout.Label("Bounce Offset. " + _lightBleeding.normalOffset.ToString("0.0"));
		_lightBleeding.normalOffset = GUILayout.HorizontalSlider(_lightBleeding.normalOffset, 0f, 10.0f);
		GUILayout.Label("Resolution " + _lightBleeding.voxelSize);
		_lightBleeding.voxelSize = (int)GUILayout.HorizontalSlider((int)_lightBleeding.voxelSize, 1f, 64.0f);
		GUILayout.Label("Blur Steps " + _lightBleeding.propogationSteps);
		_lightBleeding.propogationSteps = (int)GUILayout.HorizontalSlider((int)_lightBleeding.propogationSteps, 1f, 64.0f);

		var style = GUI.skin.box;
		style.alignment = TextAnchor.MiddleLeft;

		GUILayout.Box("W/S A/D rotate light", style);
		GUILayout.Box("Control + mouse to look around.", style);
	}
}
