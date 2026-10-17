using UnityEngine;
using UnityEngine.UI;

public class EnemyController : MonoBehaviour, IDamageable
{
    [SerializeField] private int initialLife = 100;
    private int life;
    private GameObject player;

    [SerializeField] private float speed = 1.5f;

    [Header("UI")]
    [SerializeField] private Slider healthSlide;

    private SpriteRenderer spriteRenderer;


    private Rigidbody2D rb2D;

    public void TakeDamage(int damage)
    {
        life -= damage;
        healthSlide.value = life;

        if (life <= 0)
        {
            Destroy(gameObject);
        }
    }

    void Start()
    {
        rb2D = GetComponent<Rigidbody2D>();
        spriteRenderer = GetComponent<SpriteRenderer>();

        player = GameObject.FindWithTag("Player");
        life = initialLife;

        healthSlide.value = initialLife;
    }

    void FixedUpdate()
    {
        Vector3 dir = (player.transform.position - rb2D.transform.position).normalized;

        if (Vector3.Distance(player.transform.position, rb2D.transform.position) > 1.0f)
        {
            rb2D.MovePosition(rb2D.transform.position + dir * speed * Time.fixedDeltaTime);
        }

        spriteRenderer.flipX = transform.localScale.x < 0;
    }
}
