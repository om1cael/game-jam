using UnityEngine;
using UnityEngine.AI;
using UnityEngine.UI;
using Pathfinding;


public class EnemyController : MonoBehaviour, IDamageable
{
    [SerializeField] private int initialLife = 100;
    private int life;
    private GameObject player;

    [SerializeField] private float speed = 1.5f;

    [Header("UI")]
    [SerializeField] private Slider healthSlide;

    private SpriteRenderer spriteRenderer;
    private Animator animator;


    [SerializeField] private ParticleSystem deathParticle;

    private Rigidbody2D rb2D;

    private AIPath path;

    public AudioClip hitSound;


    public void TakeDamage(int damage)
    {
        life -= damage;
        healthSlide.value = life;
        animator.SetTrigger("damage");

        if (life <= 0)
        {
            Instantiate(deathParticle, transform.position, Quaternion.identity);
            Destroy(gameObject);
        }

        Vector2 knockbackDirection = -transform.right;

        rb2D.linearVelocity = Vector2.zero; // Reseta a velocidade atual (se Unity antigo, use rb2D.velocity)
        rb2D.AddForce(knockbackDirection * 20f, ForceMode2D.Impulse);

        AudioManager.Instance.PlaySFX(hitSound);
    }

    void Start()
    {
        rb2D = GetComponent<Rigidbody2D>();
        spriteRenderer = GetComponent<SpriteRenderer>();
        path = GetComponent<AIPath>();
        animator = GetComponent<Animator>();

        player = GameObject.FindWithTag("Player");
        life = initialLife;

        healthSlide.value = initialLife;
    }

    void FixedUpdate()
    {
        path.maxSpeed = speed;
        path.destination = player.transform.position;

        spriteRenderer.flipX = player.transform.position.x < transform.position.x;

    }
}
