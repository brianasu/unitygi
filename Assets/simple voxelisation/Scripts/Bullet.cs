using UnityEngine;
using System.Collections;

public class Bullet : MonoBehaviour 
{
	private IEnumerator Start()
	{
		Destroy(gameObject, 5.0f);
		var mat = renderer.material;
		var time = 0f;
		while(true)
		{
			mat.color = Color.Lerp(Color.white, Color.black, time);
			time += Time.deltaTime / 5f;
			yield return null;
		}
	}
}
