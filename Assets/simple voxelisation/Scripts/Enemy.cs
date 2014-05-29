using UnityEngine;
using System.Collections;

public class Enemy : MonoBehaviour {

	public float enemySpeed = 1f;

	void Start () 
	{
		transform.position = Vector3.forward * -20;
		transform.position += Vector3.right * Mathf.Round(Random.Range(-6, 6) / 2) * 2;
		transform.position += Vector3.up * Random.Range(0, 2) * 2;
	}
	
	void FixedUpdate () 
	{
		rigidbody.AddForce(Vector3.forward * Time.fixedDeltaTime * enemySpeed, ForceMode.Acceleration);
		enemySpeed = Mathf.Max(enemySpeed + Time.fixedDeltaTime, 0, 5);
		if(transform.position.z > 25)
		{
			Destroy(gameObject, 3.0f);
		}
	}

	void OnCollisionEnter(Collision collision)
	{
		if(collision.collider.gameObject.layer == LayerMask.NameToLayer("bullet"))
		{
		Destroy(gameObject, 3.0f);
		}
		}
}
