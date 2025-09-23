# Tareas Pendientes de la Aplicación

Esta es una lista de tareas importantes y mejoras de seguridad que deben ser implementadas antes de que la aplicación pase a un entorno de producción.

## 1. Implementar Flujo de "Olvidé mi Contraseña"

- **Tarea:** Crear una pantalla y la lógica de backend necesaria para que los usuarios puedan solicitar un restablecimiento de contraseña. Esto podría implicar el envío de un correo electrónico con un enlace o código de un solo uso.

- **Razón:** Es una funcionalidad esencial para cualquier sistema de autenticación, ya que permite a los usuarios recuperar el acceso a sus cuentas si olvidan su contraseña. La opción fue deshabilitada temporalmente de la pantalla de login.

- **Solución Propuesta:**
  1. Crear una nueva pantalla "Recuperar Contraseña" donde el usuario ingrese su correo electrónico.
  2. Desarrollar una función de backend (RPC o Edge Function) que genere un token de restablecimiento, lo guarde en la base de datos con una fecha de expiración y envíe un correo al usuario con un enlace.
  3. Crear una pantalla "Restablecer Contraseña" donde el usuario, al llegar desde el enlace, pueda ingresar y confirmar su nueva contraseña.

## 1. Filtrar Ubicaciones para Residentes en Creación de Incidentes

- **Tarea:** Modificar el formulario de creación de incidentes para que los residentes solo puedan seleccionar su propia ubicación o áreas comunes relevantes, en lugar de ver todas las ubicaciones de la organización.

- **Razón:** Mejora la experiencia del usuario, simplifica la interfaz y previene que se creen tickets en ubicaciones incorrectas que no corresponden al residente.

---

## 1. Implementar Subida Segura de Archivos

- **Tarea:** Refactorizar la subida de fotos de perfil para que se realice a través de una función de backend (por ejemplo, una Supabase Edge Function) en lugar de directamente desde el cliente.

- **Razón:** La aplicación utiliza un sistema de autenticación personalizado (la tabla `users`) en lugar de Supabase Auth. El método actual para subir archivos requiere políticas de seguridad de almacenamiento muy permisivas que son inseguras para producción. Un atacante podría subir archivos no autorizados a nuestro bucket de almacenamiento.

- **Solución Propuesta:**
  1. Crear una Edge Function en Supabase.
  2. El cliente (la app de Flutter) debe llamar a esta función pasándole el archivo a subir.
  3. La Edge Function, que se ejecuta en un entorno seguro y utiliza una clave de servicio (`service_role_key`), debe verificar la identidad del usuario y luego subir el archivo al bucket de Supabase Storage en su nombre.
  4. Reemplazar las políticas de almacenamiento permisivas actuales por unas más restrictivas que solo permitan el acceso a través de esta Edge Function.
