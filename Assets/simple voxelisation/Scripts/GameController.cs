using UnityEngine;
using System.Collections;
using System.Collections.Generic;

public class GameController : MonoBehaviour {

	public Camera cam;

	public Light sunLight;

	public float speed = 10;

	public Bullet bulletPrefab;

	public Enemy[] enemyPrefab;

	public Transform player;
	public Transform playerMarker;

	private List<Enemy> _enemies;

	private IEnumerator Start () 
	{
		_enemies = new List<Enemy>();

		var yieldFrame = new WaitForEndOfFrame();
		var time = 0f;
		var enemySpawnTime = 3f;

		while(true)
		{
//			sunLight.color = Color.Lerp(sunColors[Mathf.FloorToInt(colors)], sunColors[Mathf.FloorToInt(colors) + 1], colors % 1);
//			colors += Time.deltaTime * 0.1f;
//			if(colors > sunColors.Length - 1)
//			{
//				colors = 0;
//			}

			time += Time.deltaTime;
			enemySpawnTime -= Time.deltaTime;

			if(enemySpawnTime < 0)
			{
				enemySpawnTime = 3f;
				var enemy  = GameObject.Instantiate(enemyPrefab[Random.Range(0, enemyPrefab.Length)]) as Enemy;
				_enemies.Add(enemy);
			}

			var pos = player.transform.position;
			pos -= Vector3.right * Input.GetAxis("Horizontal") * Time.deltaTime * speed;
			pos.x = Mathf.Clamp(pos.x, -6, 6);
			player.position = pos;

			pos.x = Mathf.Round(pos.x / 2) * 2;
			playerMarker.position = pos;

			yield return yieldFrame;
		}
	}

	private void Update()
	{
		if(Input.GetKeyDown(KeyCode.Space))
		{
			var spawnPos = Vector3.right * Mathf.Round(player.transform.position.x / 2) * 2;
			spawnPos.z = player.transform.position.z;
			while(Physics.CheckSphere(spawnPos, 0.25f))
			{
				spawnPos += Vector3.up * 2;
			}
			var bulletInst = GameObject.Instantiate(bulletPrefab, spawnPos, Quaternion.identity) as Bullet;
		}
	}


}
