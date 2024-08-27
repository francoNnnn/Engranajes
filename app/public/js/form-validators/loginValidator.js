
function LoginValidator()
{
// bind a simple alert window to this controller to display any errors //
	this.loginErrors = $('.modal-alert');
	
	this.showLoginError = function(t, m)
	{
		$('.modal-alert .modal-header h4').text(t);
		$('.modal-alert .modal-body').html(m);
		this.loginErrors.modal('show');
	}
}

LoginValidator.prototype.validateForm = function()
{
	if ($('#user-tf').val() == ''){
		this.showLoginError('¡Ups!', 'Ingresa un nombre de usuario válido por favor');
		return false;
	}	else if ($('#pass-tf').val() == ''){
		this.showLoginError('¡Ups!', 'Ingresa una contraseña válida por favor');
		return false;
	}	else{
		return true;
	}
}