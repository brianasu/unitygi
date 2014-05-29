using UnityEngine;
using System.Collections;

public class Rotate : MonoBehaviour 
{
	public Vector3 _rotationSpeed;

	private void Update () 
	{
		transform.Rotate(_rotationSpeed * Time.deltaTime);
	}
}
