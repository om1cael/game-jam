{
    void TakeDamage(int damage);
}

public class EnemyController : MonoBehaviour, IDamageable, IEnemyController
{
    [SerializeField] private int initialLife = 100;
    [SerializeField] private float speed = 1.5f;

    [Header("UI")]
    [SerializeField] private Slider healthSlide;

    private int life;
    private GameObject player;
    private SpriteRenderer spriteRenderer;
    private Rigidbody2D rb2D;

    private void Awake()
    {
        rb2D = GetComponent<Rigidbody2D>();
        spriteRenderer = GetComponent<SpriteRenderer>();
    }

    private void Start()
    {
        player = GameObject.FindWithTag("Player");
        life = initialLife;
        UpdateHealthBar();
    }

    private void FixedUpdate()
    {
        if (player == null || rb2D == null)
            return;

        Vector3 direction = player.transform.position - rb2D.transform.position;
        float distanceToPlayer = direction.magnitude;

        if (distanceToPlayer > 1.0f)
        {
            direction = direction.normalized;
            rb2D.MovePosition(rb2D.transform.position + direction * speed * Time.fixedDeltaTime);
        }

        if (spriteRenderer != null)
        {
            spriteRenderer.flipX = direction.x < 0f;
        }
    }

    public void TakeDamage(int damage)
    {
        if (damage <= 0)
            return;

        life = Mathf.Max(0, life - damage);
        UpdateHealthBar();

        if (life <= 0)
        {
            Destroy(gameObject);
        }
    }

    private void UpdateHealthBar()
    {
        if (healthSlide != null)
        {
            healthSlide.maxValue = initialLife;
            healthSlide.value = life;
        }
    }

    private void OnValidate()
    {
        initialLife = Mathf.Max(1, initialLife);
        speed = Mathf.Max(0f, speed);
    }
}
