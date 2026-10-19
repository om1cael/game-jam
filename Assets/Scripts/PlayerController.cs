using TMPro;
using Unity.Mathematics;
using UnityEngine;

public class PlayerController : MonoBehaviour
{
    [SerializeField] float speed = 8;

    [Header("Boundaries")]
    [SerializeField] private Vector2 minBounds = new Vector2(-7, -5);
    [SerializeField] private Vector2 maxBounds = new Vector2(7, 5);

    private InputSystem_Actions inputActions;
    private Rigidbody2D rb2D;

    private Vector2 movementInput;


    private bool mouseWarningLogged;

    private int life = 5;

    public ParticleSystem dieParticle;

    public TMP_Text lifesText;

    private Animator animator;

    private SpriteRenderer spriteRenderer;


    void Awake()
    {
        inputActions = new InputSystem_Actions();
    }

    void Start()
    {
        rb2D = GetComponent<Rigidbody2D>();
        animator = GetComponent<Animator>();
        spriteRenderer = GetComponent<SpriteRenderer>();

        Cursor.lockState = CursorLockMode.None;
        Cursor.visible = true;
    }

    void OnEnable()
    {
        GameEvents.OnAllHordesDefeated += HideOnEnd;
        inputActions.Player.Enable();
    }

    void OnDisable()
    {
        GameEvents.OnAllHordesDefeated -= HideOnEnd;
        inputActions.Player.Disable();
    }

    void FixedUpdate()
    {
        movementInput = inputActions.Player.Move.ReadValue<Vector2>();
        Vector2 movement = new Vector2(movementInput.x, movementInput.y);
        rb2D.linearVelocity = movement * speed;

        Vector2 position = rb2D.position;

        position.x = Mathf.Clamp(position.x, minBounds.x, maxBounds.x);
        position.y = Mathf.Clamp(position.y, minBounds.y, maxBounds.y);

        rb2D.position = position;

        float move = Mathf.Abs(movement.magnitude);
        animator.SetFloat("movement", move);

        if (movementInput.x != 0)
        {
            spriteRenderer.flipX = movementInput.x < 0;
        }
    }

    void OnCollisionEnter2D(Collision2D collision)
    {
        if (collision.gameObject.CompareTag("Enemy"))
        {
            if (life != 0)
            {
                life--;
            }
            lifesText.text = life + " vidas";

            if (life < 1)
            {
                Instantiate(dieParticle, transform.position, Quaternion.identity);
                Invoke("HideOnEnd", 0.3f);
                GameEvents.OnPlayerDie.Invoke();
            }
        }
    }

    void HideOnEnd()
    {
        gameObject.SetActive(false);
    }
}
