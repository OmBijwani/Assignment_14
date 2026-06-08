def calculator(a, b, oprn):
    if oprn == 'Add':
        return a + b

    if oprn == 'Sub':
        return a - b

    if oprn == 'Multiply':
        return a * b

    if oprn == 'Division':
        return a / b

    if oprn == 'Power':
        pass

a = int(input("Enter A: "))
b = int(input("Enter B: "))

print("""Available Operations: 
Add 
Sub 
Multiply
Division
Power""")

oprn = input("Enter Operation: ")

result = calculator(a, b, oprn)

print("RESULT:", result)