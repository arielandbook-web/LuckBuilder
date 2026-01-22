// lib/paywall/paywall_state.dart
import 'package:equatable/equatable.dart';

enum PaywallStatus { locked, purchasing, unlocked, error }

class PaywallState extends Equatable {
  final PaywallStatus status;
  final String? errorMessage;

  const PaywallState({
    required this.status,
    this.errorMessage,
  });

  const PaywallState.locked() : this(status: PaywallStatus.locked);

  const PaywallState.purchasing() : this(status: PaywallStatus.purchasing);

  const PaywallState.unlocked() : this(status: PaywallStatus.unlocked);

  const PaywallState.error(String msg)
      : this(status: PaywallStatus.error, errorMessage: msg);

  PaywallState copyWith({
    PaywallStatus? status,
    String? errorMessage,
  }) {
    return PaywallState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
