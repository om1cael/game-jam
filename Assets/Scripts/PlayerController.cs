using Unity.Mathematics;
using UnityEngine;

public class PlayerController : MonoBehaviour
{
    [SerializeField] float speed = 8;

    public InputSystem_Actions inputActions;
    private Rigidbody2D rb2D;

    private Vector2 movementInput;

    private Camera cam;



    void Awake()
    {
        inputActions = new InputSystem_Actions();
    }

    void Start()
    {
        rb2D = GetComponent<Rigidbody2D>();
        cam = Camera.main;

        Cursor.lockState = CursorLockMode.Locked;

    }

    void OnEnable()
    {
        Debug.Log(inputActions);
        inputActions.Player.Enable();
    }

    void OnDisable()
    {
        inputActions.Player.Disable();
    }

    void FixedUpdate()
    {
        movementInput = inputActions.Player.Move.ReadValue<Vector2>();
        Vector2 movement = new Vector2(movementInput.x, movementInput.y);
        rb2D.linearVelocity = movement * speed;
    }

    void Update()
    {
        Vector2 mouseScreenPos = inputActions.Player.Look.ReadValue<Vector2>();

        Vector3 mousePos = cam.ScreenToWorldPoint(new Vector3(
            mouseScreenPos.x,
            mouseScreenPos.y,
            Mathf.Abs(cam.transform.position.z - transform.position.z)
        ));


        Vector2 direction = mousePos - transform.position;
        float angle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;

        transform.rotation = Quaternion.Euler(0f, 0f, angle);
    }
}
