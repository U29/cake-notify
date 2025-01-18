mkdir -p package
pip install --target ./package -r requirements.txt
cd package
zip -r -q ../lambda_function.zip .
cd ..
zip -q lambda_function.zip lambda_function.py