using System.Collections;
using UnityEngine;

public class BulletController : MonoBehaviour
{
    private Rigidbody2D rb2D;
    private Vector2 direction;
    private GameObject gun;


    void Start()
    {
        rb2D = GetComponent<Rigidbody2D>();
        gun = GameObject.FindWithTag("Gun");

        direction = transform.position - gun.transform.position;

        StartCoroutine(DestroyBullet());
    }

    void FixedUpdate()
    {
        rb2D.linearVelocity = direction * 10.0f;
    }

    void OnCollisionEnter2D(Collision2D collision)
    {
        if (collision.collider.TryGetComponent(out IDamageable damageable))
        {
            damageable.TakeDamage(5);
        }

        Destroy(gameObject);
    }

    private IEnumerator DestroyBullet()
    {
        yield return new WaitForSeconds(1.5f);
        Destroy(gameObject);
    }
}